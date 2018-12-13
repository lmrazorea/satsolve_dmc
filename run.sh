#!/bin/bash

#set -x


PROBLEM_DIR="$1"

PROBLEM_SELECTOR="$2"

DURATION="$3"

OUTPUT_DIR="$4"

DEFINED_TRIAL_COUNT="10"

OUTPUT_SEPARATOR="==========================================="


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


# The TOTAL_[...] variables represent statistics over the entire problem set defined by 'PROBLEM_SELECTOR'.
TOTAL_TRIAL_COUNT=0
TOTAL_SUCCESS_COUNT=0
TOTAL_RUNTIME=0.0

run_problem_instance() {
	problem_file_name="$1"

	problem_instance_path=$PROBLEM_DIR/$problem_file_name
	min_clauses_not_matched=$(grep ${problem_file_name:3} $PROBLEM_DIR/a-h.3sat.solutions.txt | cut -d= -f2)
	if [ -z $min_clauses_not_matched ] ; then
		echo "[run.sh] Error: 'min_clauses_not_matched' is empty."
		exit 1
	fi
	
	# Parse the relevant details (the digest) from the output of the sat solver. Also, save to log files both the entire output and this digest.
	output_digest=$(./sweepsat  $problem_instance_path $DURATION $DEFINED_TRIAL_COUNT | tee $OUTPUT_DIR/log.$problem_file_name.$DURATION.txt | grep -e trial -e instance-execution -e "Best solutions found have $min_clauses_not_matched" | tee $OUTPUT_DIR/log-digest.$problem_file_name.$DURATION.txt)

	# Count trials over the entire problem set.
	trial_count=$(echo "$output_digest" | grep -w trial | wc -l)
	if [ "$DEFINED_TRIAL_COUNT" != "$trial_count" ] ; then
		echo "[run.sh] Error: $DEFINED_TRIAL_COUNT is different from $trial_count"
		exit 1
	fi
	((TOTAL_TRIAL_COUNT+=trial_count))

	# Calculate the success ratio over the entire problem set.
	success_count=$(echo "$output_digest" | grep "Best solutions found have" | wc -l)
	((TOTAL_SUCCESS_COUNT+=success_count))

	# Calculate the runtime over the entire problem set.
	problem_runtime=$(echo "$output_digest" | grep instance-execution | grep -Eo 'runtime:.*' | parse_float)
	TOTAL_RUNTIME=$(echo "scale=6; $TOTAL_RUNTIME + $problem_runtime" | bc | awk '{printf "%f", $0}')

	success_ratio=$(echo "scale=6; $success_count / $trial_count" | bc | awk '{printf "%f", $0}')
	echo "instance-success-ratio: $success_ratio ($success_count/$trial_count)"
	echo "instance-runtime: $problem_runtime"
	echo "$output_digest" | grep instance-execution
}


parse_float() {
	read line
	echo $line | grep -Eo '[0-9]+([.][0-9]+)?'
}

make 

echo "[run.sh] >>> Problem selector: $PROBLEM_SELECTOR; Duration: $DURATION"

for filename in $(select_problems) ; do 
	echo $OUTPUT_SEPARATOR
	run_problem_instance $filename
done

echo $OUTPUT_SEPARATOR

PROBLEM_SET_SUCCESS_RATIO=$(echo "scale=6; $TOTAL_SUCCESS_COUNT / $TOTAL_TRIAL_COUNT" | bc | awk '{printf "%f", $0}')
echo "problem-set-success-ratio: $PROBLEM_SET_SUCCESS_RATIO ($TOTAL_SUCCESS_COUNT/$TOTAL_TRIAL_COUNT)"

AVG_PROBLEM_SET_RUNTIME=$(echo "scale=6; $TOTAL_RUNTIME / $TOTAL_TRIAL_COUNT" | bc | awk '{printf "%f", $0}')
PROBLEM_SET_SCORE=$(echo "scale=6; ($AVG_PROBLEM_SET_RUNTIME / $PROBLEM_SET_SUCCESS_RATIO)" | bc | awk '{printf "%f", $0}')
echo "problem-set-score: $PROBLEM_SET_SCORE"

echo "total-runtime: $TOTAL_RUNTIME"
