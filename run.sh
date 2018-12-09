#!/bin/bash

#set -x


PROBLEM_DIR="$1"

PROBLEM_SELECTOR="$2"

DURATION="$3"

OUTPUT_SEPARATOR="========================================================================================="


select_problems() {
	case $PROBLEM_SELECTOR in
		"all")
			echo $(cd $PROBLEM_DIR && ls *.cnf)
			;;
		"v90c700")
			echo $(cd $PROBLEM_DIR && ls *.cnf | grep v90c700)
			;;
		"v110c700")
			echo $(cd $PROBLEM_DIR && ls *.cnf | grep v110c700)
			;;
		*)
			# Pad with 0 to have a fixed width number.
			problem_instance_nr=$(printf "%0*d" 2 $PROBLEM_SELECTOR) 
			# Print file name.
			echo $(cd $PROBLEM_DIR && ls ${problem_instance_nr}-*.cnf)
			;;
	esac
}


TOTAL_TRIAL_COUNT=0
TOTAL_SUCCESS_RATIO=0

run_problem_instance() {
	problem_file_name="$1"

	problem_instance_path=$PROBLEM_DIR/$problem_file_name
	min_clauses_not_matched=$(grep ${problem_file_name:3} $PROBLEM_DIR/a-h.3sat.solutions.txt | cut -d= -f2)
	if [ -z $min_clauses_not_matched ] ; then
		echo "[run.sh] Error: 'min_clauses_not_matched' is empty."
		exit 1
	fi
	
	output_digest=$(./sweepsat.exe  $problem_instance_path $DURATION | tee log.$problem_file_name.$DURATION.txt | grep -e trial -e instance-execution -e "Best solutions found have $min_clauses_not_matched" | tee /dev/tty)

	trial_count=$(echo $output_digest | grep -o trial | wc -l)
	((TOTAL_TRIAL_COUNT+=trial_count))
	success_count=$(echo $output_digest | grep -o Best | wc -l)
	((TOTAL_SUCCESS_RATIO+=success_count))
	echo "instance-success-ratio: $success_count/$trial_count"
}

make 

echo "[run.sh] >>> Problem selector: $PROBLEM_SELECTOR; Duration: $DURATION"

for filename in $(select_problems) ; do 
	echo $OUTPUT_SEPARATOR
	run_problem_instance $filename
done

echo $OUTPUT_SEPARATOR

echo "total-success-ratio: $TOTAL_SUCCESS_RATIO/$TOTAL_TRIAL_COUNT"
