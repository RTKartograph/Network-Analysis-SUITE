#/usr/bin/env bash

# Arguments
iface=""
network_cidr=""
timeout=1
pp=50

ip2int() {
	local a b c d ip=$1 
	IFS=. read -r a b c d <<< "$1"
	printf '%u\n' "$((a * 256 ** 3 + b * 256 ** 2 + c * 256 + d ))"
}

int2ip() {
	local ip delim dec=$1
	for e in {3..0}
	do
		((octet = dec / (256 ** e) ))
		((dec -= octet * 256 ** e))
		ip+=$delim$octet
		delim=.
	done
	printf '%s\n' "$ip"
}

cidr2netmask() {
	local cidr=$1
	if (( cidr == 0 )); then
		echo 0
		return
	fi
	local mask=$(( (0xFFFFFFFF << (32 - cidr)) & 0xFFFFFFFF ))
	printf '%u\n' "$mask"

}

for i in "$@"; do
	case $i in
		-i=* | --interface=*)
			iface="${i#*=}"
			shift
			;;
		-n=* | --network=*)
			network_cidr="${i#*=}"
			shift
			;;
		-t=* | --timeout=*)
			timeout="${i#*=}"
			shift
			;;
		-p=* | --parallel=*)
			pp="${i#*=}"
			shift
			;;
	esac
done

if [[ "$network_cidr" != */* ]]; then
	echo "Network must be in CIDR form! e.g. 192.168.0.1/24" >&2
	exit 1
fi
network="${network_cidr%/*}"
cidr="${network_cidr##*/}"

network2int=$(ip2int "$network")
cidr2mask=$(cidr2netmask "$cidr")
network_base=$(( network2int & cidr2mask ))
broadcast=$(( network_base | ((~cidr2mask) & 0xFFFFFFFF) ))

# Skip network and broadcast addresses
start_ip=$(( network_base + 1 ))
end_ip=$(( broadcast - 1 ))

printf "Start IP:%s\nEnd_IP:%s\n" $start_ip, "$end_ip"

if (( start_ip > end_ip )); then
	echo "No hosts to scan." >&2
	exit 1
fi

job_count=0
scan_job() {
	local ip=$1
	local local_timeout=$2
	local local_iface=$3
	
	arping -c 1 -w "$local_timeout" -I "$iface_local" "$ip" >/dev/null 2>&1
	if [[ $? -eq 0 ]]; then
		# ARP reply received
		mac=$(ip neigh show "$ip" 2>/dev/null)
		mac=${mac:-unknown}
		printf '%s\t$s\n' "$ip" "$mac"
	fi
}

export -f scan_job

echo "Scanning $network_cidr on interface $iface..."
echo "Results:"
printf "%-16s %n" "IP" "MAC"
for (( ip=start_ip; ip<=end_ip; ip++ )); do
	ip_str=$(int2ip "$ip")
	scan_job "$ip_str" "$timeout" "$iface" &
	((job_count++))

	if (( job_count >= parallel )); then
		wait -n
		job_count=$(jobs -p | wc -l)
	fi
done

wait

echo "Scan finished."
