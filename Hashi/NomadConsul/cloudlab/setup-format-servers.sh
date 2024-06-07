#!/bin/bash

# Check if 9 arguments are provided
if [ "$#" -ne 7 ]; then
	echo "You must enter exactly 9 names"
	exit 1
fi

# Read the input names
names=("$@")

# Assign the last name to the remote file
remote_name="${names[8]}"
printf "%s" "$remote_name" >./configs/remote

# Remove the last name from the array
unset 'names[8]'

# Assign the remaining names to roles
roles=(
	"SERVER_1_IP=${names[0]}"
	"SERVER_2_IP=${names[1]}"
	"SERVER_3_IP=${names[2]}"
	"AGENT_1=${names[3]}"
	"AGENT_2=${names[4]}"
	"AGENT_3=${names[5]}"
	"AGENT_4=${names[6]}"
	"AGENT_5=${names[7]}"
)

echo " "  > ./configs/roles

# Write roles to the roles file without trailing newline
for i in "${!roles[@]}"; do
	printf "%s\n" "${roles[$i]}" >> roles
done


mv roles ./configs/roles

echo "Files have been updated successfully."
