#!/bin/bash

# get the file contents and assign them into appropriate arrays:
process_names=()
initial_arrival=()
running_arrival=()
initial_burst=()
# We use this to keep track of the temporary burst times because burst time changes as processes are partially completed
running_burst=()
# The queue will contain the index of the processes currently waiting in queue.
queue=()

#  0  1 2 3  4 5 6  7 8
#  1  2 3 4 5 6 7 8 9
#  1  2 0  1 2 0 1 2 0
# [p1 1 2 p2 2 3 p3 0 4]
# A function to read the provided file. TODO: Can be made much simpler with `while read line`.
extract_variables () {
    content_arr=($@)
    for index in "${!content_arr[@]}"
    do
        :
        input=${content_arr[$index]}
        position=$((($index + 1) % 3))

        if [ $position -eq 1 ];
        then
            process_names+=($input)
        elif [ $position -eq 2 ];
        then
            initial_arrival+=($input)
            running_arrival+=($input)
        elif [ $position -eq 0 ]
        then
            initial_burst+=($input)
            running_burst+=($input)
        fi
    done
}



if test $# -ne 1  #testing number of positional parameters
then
echo "Please provide a single parameter"
exit 1
fi
if test -f $1
then
echo "$1 is a regular file"

cat $1 ; echo ""

# -------- THE FOLLOWING ARE NO LONGER NECESSARY AND CAN BE REMOVED -----------
# echo "Filename is: $1"

# count=(`cat $1`)  #display our file on screen and save it to a variable called count
# count2=${#count[*]}
# echo
# echo "$count2"  #displays the number of elements in the array



# number of processes is the number of lines in the file
# nprocesses=(`grep -c ^ $1`)
# echo "There are $nprocesses processes"

# -----------------------------------------------------------------------------

# Get file contents into an array [p1 1 2 p2 2 3 p3 0 4]
file_contents=$(<$1)

input_arr=($file_contents)

extract_variables "${input_arr[@]}"

echo "Burst Times: ${initial_burst[@]}"
echo "Arrival Times: ${initial_arrival[@]}"

printf "%s\t" "T"$'\t'"${process_names[@]}"; echo ""

# running process is initially empty
running_process_index=""
time=0
quanta=1

# initialize statuses
statuses=()
for i in "${!process_names[@]}"; do
    statuses+=("-")
done

while [ 1 -eq 1 ]; do
    # Terminate if all processes are done
    allDone=1
    for burst_time in "${running_burst[@]}"; do
        # If any of them is not done yet
        if [[ "$burst_time" -gt "0" ]]; then
            # set allDone to false
            allDone=0
        fi
    done

    # If allDOne is true, then all is done. exit
    if [[ "$allDone" = "1" ]]; then
        break
    fi

    # Set running process. If queue is empty, first item with arrival_time = 0 on running_arrival will be running. This will only apply in the first iteration when we have not yet updated the queue.
    if [[ -z "$queue" ]]; then
        for i in "${!running_arrival[@]}"; do
            if [[ "${running_arrival[$i]}" = "0" ]]; then
                if [[ "${running_burst[$i]}" -le "0" ]]; then
                    continue
                fi
                running_process_index=$i
                # Once an item is running, recuce the burst time left
                running_burst[$i]=$(( ${running_burst[$i]} - 1 ))
                break
            fi
        done

        # if there is nothing running, run the next item with lowest arrival time. I don't believe this is round robin behaviour
        if [[ -z $running_process_index ]]; then
            # set lowest_arrival_time to maximum possible integer
            lowest_at=2147483647
            for i in "${!running_arrival[@]}"; do
                if [[ "${running_arrival[$i]}" -lt "$lowest_at" ]] && [[ "${running_arrival[$i]}" -gt "0" ]]; then
                    if [[ "${running_burst[$i]}" -le "0" ]]; then
                        continue
                    fi
                    running_process_index=$i
                    # Once an item is running, recuce the burst time left
                    running_burst[$i]=$(( ${running_burst[$i]} - 1 ))
                    break
                fi
            done
        fi

    elif [[ -n "$queue" ]]; then
        running_process_index="${queue[0]}"
        running_burst[$running_process_index]=$(( ${running_burst[$running_process_index]} - 1 ))
        queue=("${queue[@]:1}")
    fi

    if [[ "$time" -gt "0" ]]; then
        for i in "${!running_arrival[@]}"; do
            # if the item is running, or is in the queue, reset its arrival time to initial arrival time
            if [[ "$i" = "$running_process_index" ]] || [[ ${queue[*]} =~ "$i" ]]; then
                running_arrival[$i]=${initial_arrival[$i]}
            else
                running_arrival[$i]=$(( ${running_arrival[$i]} - 1 ))
                # If the arrival time is 0, and the item is not currently in the queue, the item is not currently running, and the item is not done, then add it to the queue
                if [[ "${running_arrival[$i]}" -le "0" ]] && ! [[ ${queue[*]} =~ "$i" ]] && ! [[ "$i" = "$running_process_index" ]] && [[ "${running_burst[$i]}" -gt "0" ]]; then
                    queue+=($i)
                fi
            fi
        done
    fi

    # ------------------ USEFUL FOR DEBUGGING -------------------
    # queue_names=()
    # for i in "${queue[@]}"; do
    #     queue_names+=(${process_names[$i]})
    # done

    # if [[ -n "$running_process_index" ]]; then running_process_name=${process_names[$running_process_index]}; else running_process_name=""; fi

    # echo "Running arrival: ${running_arrival[@]}"
    # echo "Running burst: ${running_burst[@]}"
    # echo "Running queue: ${queue_names[@]}"
    # echo "Running: $running_process_name"
    # echo "Time: $time"
    # /------------------ USEFUL FOR DEBUGGING -------------------

    for i in "${!process_names[@]}"; do
        if [[ "$running_process_index" = $i ]]; then
            statuses[$i]="R"
        elif [[ ${running_burst[$i]} -le "0"  ]]; then
            statuses[$i]="F"
        elif [[ ${queue[*]} =~ "$i" ]]; then
            statuses[$i]="W"
        fi
    done

    printf "%s\t" "$time"$'\t'"${statuses[@]}"; echo ""

    # increment time
    time=$(( $time + $quanta ))

    # Unset the running status of the current running process. This is a hack
    statuses[$running_process_index]="W"
    # unset running process
    running_process_index=""
done


#  Print the final statuses
for i in "${!process_names[@]}"; do
    if [[ "$running_process_index" = $i ]]; then
        statuses[$i]="R"
    elif [[ ${running_burst[$i]} -le "0"  ]]; then
        statuses[$i]="F"
    elif [[ ${queue[*]} =~ "$i" ]]; then
        statuses[$i]="W"
    fi
done

printf "%s\t" "$time"$'\t'"${statuses[@]}"; echo ""

echo "Total TurnAround Time is $time"



elif test -d $1
then
echo "$1 is a directory"
fi
