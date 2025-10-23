#/usr/bin/env bash

# Arguments
iface=""
network_cidr=""
timeout=1
pp=50
out_csv=""

usage() {
	cat <<EOF
Usage: $0 -i=interface -n=network[/cidr] [-t=timeout] [-p=parallel] [-o=out.csv]

Example: sudo $0 -i=eth0 -n=192.168.1.0/24 -t=1 -p=50 -o=list.csv

Options:
	-i iface	Network interface to use (Required)
	-n network	Network in CIDR Notation (Required), e.g. 192.168.1.0/24
	-t timeout	Arping timeout in seconds (default: 1)
	-p parallel	How many requests done in parallel (default: 50)
	-o output	Generates CSV output file
EOF
	exit 1
}

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
			;;
		-n=* | --network=*)
			network_cidr="${i#*=}"
			;;
		-t=* | --timeout=*)
			timeout="${i#*=}"
			;;
		-p=* | --parallel=*)
			pp="${i#*=}"
			;;
		-o=* | --output=*)
			out_csv="${i#*=}"
			;;
		-h | --help )
			usage
			;;
		*) 
			echo "Unknown option: $i" >&2;
			usage
			;;
	esac
done

if [[ -z "$iface" || -z "$network_cidr" ]]; then
	usage
fi

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

if (( start_ip > end_ip )); then
	echo "No hosts to scan." >&2
	exit 1
fi

job_count=0
scan_job() {
	local ip=$1
	local local_timeout=$2
	local local_iface=$3
	
	arping -c 1 -w "$local_timeout" -I "$local_iface" "$ip" >/dev/null 2>&1
	if [[ $? -eq 0 ]]; then
		# ARP reply received
		mac=$(ip neigh show "$ip" 2>/dev/null | awk '/lladdr/ {print $5; exit}')
		mac=${mac:-unknown}
		printf '%s\t%s\n' "$ip" "$mac"
		if [[ -n "$out_csv" ]]; then
			printf "%s,%s,%s\n" "$ip" "$mac" "$iface_local" >> "$out_csv"
		fi
	fi
}

export -f scan_job

echo "Scanning $network_cidr on interface $iface..."
echo "Results:"
printf "%-16s %s\n" "IP" "MAC"
for (( ip=start_ip; ip<=end_ip; ip++ )); do
	ip_str=$(int2ip "$ip")
	scan_job "$ip_str" "$timeout" "$iface" &
	((job_count++))

	if (( job_count >= pp )); then
		wait -n
		job_count=$(jobs -p | wc -l)
	fi
done

wait

echo "Scan finished."
if [[ -n $out_csv ]]; then
	echo "Sucessfully saved in: $out_csv"
fi
