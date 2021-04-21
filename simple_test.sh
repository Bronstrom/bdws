#!/bin/sh

# This test script automates our distributed work system. When running this script, please run it as follows:
# ./simple_test [hostname] [# of workers] [test filename]
#
# [hostname] refers to the complete address with "http://" or "https://" preceding it.
# [test filename] refers to the test file located in the test directory.


PROJECT_DIRECTORY=$(pwd)

# Command-line args
hostname=$1
worker_cnt=$2
test_file=$3

# Initalize integers to be used later
supervisor_machine=5001
worker_machine=5001
window=0
pane=0

tmux has-session -t stest

if [ $? != 0 ]
  then
    # Tmux window with worker_cnt worker panes, a supervisor pane, and a client pane
    # One pane will be the supervisor on stu (stest:0.0)
    tmux new-session -s stest -n "simple-test" -d
    tmux split-window -h -t stest:$window.$pane
    tmux send-keys -t stest:$window.$pane "cd $PROJECT_DIRECTORY" Enter
    tmux send-keys -t stest:$window.$pane "cd cmd/supervisor" Enter
    tmux send-keys -t stest:$window.$pane "go build" Enter
    tmux send-keys -t stest:$window.$pane "./supervisor :$supervisor_machine" Enter
    # Setup Worker panes
    for i in $(seq 1 $worker_cnt)
      do
    	# Create Worker i (stest:window.pane) pane
	let "pane=i%20"
        tmux split-window -v -t stest:$window.$pane
	# Worker i will corespond to machine (5000 + i+1), this is offset by 1 with supervisor starting on 5001
	let "worker_machine++"
	# Check stu lab machine, when hostname contains stu
	if [[ "$hostname" == *"stu.cs.jmu.edu"* ]]
          then
            tmux send-keys -t stest:$window.$pane "ssh -o StrictHostKeyChecking=no l2$worker_machine.cs.jmu.edu" Enter
	fi
	# Startup Worker i
	tmux send-keys -t stest:$window.$pane "cd $PROJECT_DIRECTORY" Enter
        tmux send-keys -t stest:$window.$pane "cd cmd/worker" Enter
        tmux send-keys -t stest:$window.$pane "go build" Enter
        tmux send-keys -t stest:$window.$pane "sleep 1" Enter
	# Example of terminal run command with worker executable: "./worker http://stu.cs.jmu.edu:5001 5002"
        tmux send-keys -t stest:$window.$pane "./worker $hostname:$supervisor_machine $worker_machine" Enter
    	# Set tmux layout to tiled form to make room for new panels in window
    	tmux select-layout tiled
	# Check for number of workers, create new window when count is 19
	if [ $pane -eq 19 ]
	  then
	    let "window++"
	    tmux new-window -t stest:$window
        fi
    done
    # Create Client (stest:window.worker_cnt+1) pane
    let "pane++"
    let "worker_machine++"
    # Check stu lab machine, when hostname contains stu
    if [[ "$hostname" == *"stu.cs.jmu.edu"* ]]
      then
        tmux send-keys -t stest:$window.$pane "ssh -o StrictHostKeyChecking=no l2$worker_machine.cs.jmu.edu" Enter
    fi
    tmux send-keys -t stest:$window.$pane "cd $PROJECT_DIRECTORY" Enter
    tmux send-keys -t stest:$window.$pane "cd cmd/client" Enter
    tmux send-keys -t stest:$window.$pane "go build" Enter
    tmux send-keys -t stest:$window.$pane "sleep 2" Enter
    # Example of terminal run command with client executable: "./client http://stu.cs.jmu.edu:5001 test/hello.sh"
    tmux send-keys -t stest:$window.$pane "./client $hostname:$supervisor_machine $PROJECT_DIRECTORY/test/$test_file" Enter
    # Client pane should remain active
fi

# Kill Session
tmux attach -t stest
tmux kill-session -t stest
tmux kill-session -t stest

