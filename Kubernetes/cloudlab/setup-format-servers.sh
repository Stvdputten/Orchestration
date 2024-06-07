#!/bin/bash

# Check if 9 arguments are provided
if [ "$#" -ne 9 ]; then
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
	"MANAGER_1=${names[0]}"
	"MANAGER_2=${names[1]}"
	"MANAGER_3=${names[2]}"
	"WORKER_1=${names[3]}"
	"WORKER_2=${names[4]}"
	"WORKER_3=${names[5]}"
	"WORKER_4=${names[6]}"
	"WORKER_5=${names[7]}"
)

echo " "  > ./configs/roles

# Write roles to the roles file without trailing newline
for i in "${!roles[@]}"; do
	printf "%s\n" "${roles[$i]}" >> roles
done


mv roles ./configs/roles

echo "Files have been updated successfully."
