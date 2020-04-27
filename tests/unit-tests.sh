#!/usr/bin/env bash

# ===========================================================================
# Build tests
# ===========================================================================

# ---------------------------------------------------------------------------
testMakeCreatesMokctlDeploy(){
# ---------------------------------------------------------------------------

  make 2&>/dev/null
  assertTrue \
    "Check that make creates mokctl.deploy" \
    "[[ -e 'mokctl.deploy' ]]"
}

# ---------------------------------------------------------------------------
testBuildDirectoryCreation(){
# ---------------------------------------------------------------------------
# Check that all the files are created in the docker build dir

  local dir
  create_docker_build_dir >/dev/null
  dir="$DOCKERBUILDTMPDIR/mok-centos-7"
  assertTrue \
    "Check that tmpdir is created with the correct files" \
    "[[ -e '$dir/Dockerfile' &&
       -e '$dir/100-crio-bridge.conf' &&
       -e '$dir/entrypoint' &&
       -e '$dir/k8s.conf' &&
       -e '$dir/kubernetes.repo' &&
       -e '$dir/README.md' ]]"
}

# ---------------------------------------------------------------------------
testBuildDirectoryDeletion(){
# ---------------------------------------------------------------------------
# Check that the docker build dir is deleted

  local dir
  create_docker_build_dir >/dev/null
  cleanup
  assertTrue \
    "Check that tmpdir is deleted" "[[ ! -e $DOCKERBUILDTMPDIR ]]"
}

# ---------------------------------------------------------------------------
testBuildwithNoSubcommand(){
# ---------------------------------------------------------------------------

  main build >/dev/null
  assertEquals \
    "'mokctl build' should fail" \
    "1" "$?"
}

# ---------------------------------------------------------------------------
testBuildwithNoSubcommandOutput(){
# ---------------------------------------------------------------------------

  grabMainOutput build

  assertEquals \
    "'mokctl build' should fail with correct output" \
    "No SUBCOMMAND supplied" "${LINES[0]}"   
}

# ---------------------------------------------------------------------------
testBuildwithOption(){
# ---------------------------------------------------------------------------
# There are no options for 'build image'

  main build image 1 >/dev/null
  assertEquals \
    "'mokctl build' should fail" \
    "1" "$?"
}

# ---------------------------------------------------------------------------
testBuildwithOptionOutput(){
# ---------------------------------------------------------------------------
# There are no options for 'build image'

  grabMainOutput build image 1

  assertEquals \
    "'mokctl build' should fail with correct output" \
    "ERROR No more options expected, '1' is unexpected for 'build image'" \
    "${LINES[0]}"   
}

# ---------------------------------------------------------------------------
testBuildWouldBeStarted(){
# ---------------------------------------------------------------------------
# Override do_build_image_mutate to return an arbitrary number
# then check for that number to make sure it would have been called.
# build_container_image is tested separately so no need to test here.

  build_container_image() { return 59; }

  main build image >/dev/null
  assertEquals \
    "'mokctl build image' should call do_build_image_mutate" \
    "59" "$?"
}

# ===========================================================================
# mokctl create - no options
# ===========================================================================

# ---------------------------------------------------------------------------
testRunWithNoArgsShouldFail() {
# ---------------------------------------------------------------------------

  main >/dev/null
  assertTrue \
    "Run with no arguments should fail" \
    "[[ $? -ge 1 ]]"
}

# ---------------------------------------------------------------------------
testRunWithNoArgsShouldFailOutput() {
# ---------------------------------------------------------------------------

  do_create_cluster_mutate(){ :; }
  do_delete_cluster_mutate(){ :; }

  grabMainOutput
  
  assertEquals \
    "Run with no arguments should fail with correct output" \
    "No COMMAND supplied" "${LINES[0]}"   
}

# ===========================================================================
# mokctl create tests
# ===========================================================================

# ---------------------------------------------------------------------------
testRunWithOneArgShouldFail() {
# ---------------------------------------------------------------------------

  do_create_cluster_mutate(){ :; }

  main create >/dev/null
  assertTrue \
    "'mokctl create' should fail" \
    "[[ $? -ge 1 ]]"
}

# ---------------------------------------------------------------------------
testRunWithOneArgShouldFailOutput() {
# ---------------------------------------------------------------------------

  do_create_cluster_mutate(){ :; }

  grabMainOutput create
  
  assertEquals \
    "'mokctl create' should fail with correct output" \
    "No SUBCOMMAND supplied" "${LINES[0]}"   
}

# ---------------------------------------------------------------------------
testNotEnoughOptionsToCreateCluster() {
# ---------------------------------------------------------------------------

  do_create_cluster_mutate(){ :; }

  main create cluster >/dev/null
  assertTrue \
    "'mokctl create cluster' should fail" \
    "[[ $? -ge 1 ]]"
}

# ---------------------------------------------------------------------------
testNotEnoughOptionsToCreateClusterOutput() {
# ---------------------------------------------------------------------------

  do_create_cluster_mutate(){ :; }

  grabMainOutput create cluster
  
  assertEquals \
    "'mokctl create cluster' should fail with correct output" \
    "Please provide the Cluster NAME to create." "${LINES[0]}"   
}

# ---------------------------------------------------------------------------
testNotEnoughOptionsToCreateClusterName() {
# ---------------------------------------------------------------------------

  do_create_cluster_mutate(){ :; }

  main create cluster name >/dev/null
  assertTrue \
    "'create cluster name' should fail" \
    "[[ $? -ge 1 ]]"
}

# ---------------------------------------------------------------------------
testNotEnoughOptionsToCreateClusterNameOutput() {
# ---------------------------------------------------------------------------

  do_create_cluster_mutate(){ :; }

  grabMainOutput create cluster mycluster
  
  assertEquals \
    "'create cluster name' should fail with correct output" \
    "Please provide the number of Masters to create. Must be 1 or more." \
    "${LINES[0]}"
}

# ---------------------------------------------------------------------------
testNotEnoughOptionsToCreateClusterName1() {
# ---------------------------------------------------------------------------

  do_create_cluster_mutate(){ :; }

  main create cluster name 1 >/dev/null
  assertTrue \
    "'create cluster name 1' should fail" \
    "[[ $? -ge 1 ]]"
}

# ---------------------------------------------------------------------------
testNotEnoughOptionsToCreateClusterName1Output() {
# ---------------------------------------------------------------------------

  do_create_cluster_mutate(){ :; }

  grabMainOutput create cluster mycluster 1
  
  assertEquals \
    "'create cluster name 1' should fail with correct output" \
    "Please provide the number of Workers to create." \
    "${LINES[0]}"
}

# ---------------------------------------------------------------------------
testZeroMastersShouldFail() {
# ---------------------------------------------------------------------------
# Can't create a cluster with 0 masters

  do_create_cluster_mutate(){ :; }

  main create cluster name 0 0 >/dev/null
  assertTrue \
    "'create cluster name 0 0' should fail" \
    "[[ $? -ge 1 ]]"
}

# ---------------------------------------------------------------------------
testZeroMastersShouldFailOutput() {
# ---------------------------------------------------------------------------

  do_create_cluster_mutate(){ :; }

  grabMainOutput create cluster mycluster 0 0
  
  assertEquals \
    "'create cluster name 0 0' should fail with correct output" \
    "Please provide the number of Masters to create. Must be 1 or more." \
    "${LINES[0]}"
}

# ---------------------------------------------------------------------------
testZeroMastersShouldFail2() {
# ---------------------------------------------------------------------------
# Can't create a cluster with 0 masters and >0 workers

  do_create_cluster_mutate(){ :; }

  main create cluster name 0 1 >/dev/null
  assertTrue \
    "'create cluster name 0 0' should fail" \
    "[[ $? -ge 1 ]]"
}

# ---------------------------------------------------------------------------
testZeroMastersShouldFail2Output() {
# ---------------------------------------------------------------------------

  do_create_cluster_mutate(){ :; }

  grabMainOutput create cluster mycluster 0 1
  
  assertEquals \
    "'create cluster name 0 0' should fail with correct output" \
    "Please provide the number of Masters to create. Must be 1 or more." \
    "${LINES[0]}"
}

# ---------------------------------------------------------------------------
testValidCreateClusterCommand() {
# ---------------------------------------------------------------------------

  # Check that all the create cluster vars are set

  do_create_cluster_mutate(){ :; }

  parse_options create cluster mycluster 1 0
  assertTrue \
    "Valid command: 'mokctl create cluster name 1 0'" \
    "[[ $CREATE_CLUSTER_NAME == "mycluster" &&
       $CREATE_CLUSTER_NUM_MASTERS == "1" &&
       $CREATE_CLUSTER_NUM_WORKERS == "0" ]]"
}

# ---------------------------------------------------------------------------
testValidCreateClusterCommand2() {
# ---------------------------------------------------------------------------

  # Check that all the create cluster vars are set

  do_create_cluster_mutate(){ :; }

  parse_options create cluster mycluster 1 1
  assertTrue \
    "Valid command: 'mokctl create cluster name 1 0'" \
    "[[ $CREATE_CLUSTER_NAME == "mycluster" &&
       $CREATE_CLUSTER_NUM_MASTERS == "1" &&
       $CREATE_CLUSTER_NUM_WORKERS == "1" ]]"
}

# ---------------------------------------------------------------------------
testValidCreateClusterCommand3() {
# ---------------------------------------------------------------------------

  # Check that all the create cluster vars are set

  do_create_cluster_mutate(){ :; }

  parse_options create cluster mycluster 3 6
  assertTrue \
    "Valid command: 'mokctl create cluster name 1 0'" \
    "[[ $CREATE_CLUSTER_NAME == "mycluster" &&
       $CREATE_CLUSTER_NUM_MASTERS == "3" &&
       $CREATE_CLUSTER_NUM_WORKERS == "6" ]]"
}

# ---------------------------------------------------------------------------
testCreateClusterExtraOptions() {
# ---------------------------------------------------------------------------
# Can't create a cluster with 0 masters and >0 workers

  do_create_cluster_mutate(){ :; }

  main create cluster name 1 1 2 >/dev/null
  assertTrue \
    "'create cluster name 1 1 2' should fail" \
    "[[ $? -ge 1 ]]"
}

# ---------------------------------------------------------------------------
testCreateClusterExtraOptionsOutput() {
# ---------------------------------------------------------------------------

  do_create_cluster_mutate(){ :; }

  grabMainOutput create cluster mycluster 1 1 2
  
  assertEquals \
    "'create cluster mycluster 1 1 2' should fail with correct output" \
    "ERROR No more options expected, '2' is unexpected for 'create cluster'" \
    "${LINES[0]}"
}

# ---------------------------------------------------------------------------
testCreateClusterMutateReturnCode(){
# ---------------------------------------------------------------------------
# Override get_cluster_size to return an arbitrary number which would
# be the 'docker ps' return code

  get_cluster_size() { echo "error"; return 22; }

  do_create_cluster_mutate >/dev/null
  assertEquals \
    "docker error code should be passed back to get_cluster_size " \
    "22" "$?"
}

# ---------------------------------------------------------------------------
testGetClusterSizeReturnSize(){
# ---------------------------------------------------------------------------
# Override get_cluster_size to return an arbitrary number which would
# be the 'docker ps' return code

  docker() { echo -e "123\n234\n345\n456"; return 0; }

  numnodes=$(get_cluster_size)
  assertEquals \
    "docker num nodes should be passed back to get_cluster_size " \
    "4" "$numnodes"
}

# ---------------------------------------------------------------------------
testCreateClusterMutateFailsOnClusterExistence(){
# ---------------------------------------------------------------------------
# Override get_cluster_size to return an arbitrary number which would
# be the 'docker ps' return code

  create_master_nodes() { :; }
  create_worker_nodes() { :; }
  get_cluster_size() { echo "2"; return 0; }

  do_create_cluster_mutate >/dev/null
  assertEquals \
    "docker num nodes should be passed back to get_cluster_size " \
    "1" "$?"
}

# ---------------------------------------------------------------------------
testCreateClusterMasterNodesWithSuccess(){
# ---------------------------------------------------------------------------
# Override get_cluster_size to return an arbitrary number which would
# be the 'docker ps' return code

  docker() { sleep 1; return 0; }
  get_cluster_size() { echo "0"; return 0; }

  main create cluster myclust 1 0 >/dev/null
  r=$?
  assertEquals \
    "'mokctl create cluster myclust 1 0 should succeed" \
    "0" "$r"
}

# ---------------------------------------------------------------------------
testCreateClusterMasterNodesWithFailure(){
# ---------------------------------------------------------------------------
# Override get_cluster_size to return an arbitrary number which would
# be the 'docker ps' return code

  docker() { sleep 1; return 0; }

  # echo "1" below means that a node exists already which means
  # the cluster can't be created
  get_cluster_size() { echo "1"; return 0; }

  main create cluster myclust 1 0 >/dev/null
  r=$?
  assertEquals \
    "'mokctl create cluster myclust 1 0 should fail" \
    "1" "$r"
}

# ---------------------------------------------------------------------------
testCreateClusterMasterNodesWithFailure2(){
# ---------------------------------------------------------------------------
# Override get_cluster_size to return an arbitrary number which would
# be the 'docker ps' return code

  # return 1 below means that docker failed
  docker() { sleep 1; return 1; }
  get_cluster_size() { echo "0"; return 0; }

  main create cluster myclust 1 0 >/dev/null
  r=$?
  assertEquals \
    "'mokctl create cluster myclust 1 0 should fail" \
    "1" "$r"
}

# ===========================================================================
# mokctl delete tests
# ===========================================================================

# ---------------------------------------------------------------------------
testDeleteRunWithOneArgShouldFail() {
# ---------------------------------------------------------------------------

  main delete >/dev/null
  assertTrue \
    "Run with 'mokctl delete' should fail" \
    "[[ $? -ge 1 ]]"
}

# ---------------------------------------------------------------------------
testDeleteRunWithOneArgShouldFailOutput() {
# ---------------------------------------------------------------------------

  grabMainOutput delete
  
  assertEquals \
    "Run with 'mokctl delete' should fail with correct output" \
    "No SUBCOMMAND supplied" "${LINES[0]}"   
}

# ---------------------------------------------------------------------------
testNotEnoughOptionsToDeleteCluster() {
# ---------------------------------------------------------------------------

  main delete cluster >/dev/null
  assertTrue \
    "Run with 'mokctl delete cluster' should fail" \
    "[[ $? -ge 1 ]]"
}

# ---------------------------------------------------------------------------
testNotEnoughOptionsToDeleteClusterOutput() {
# ---------------------------------------------------------------------------

  grabMainOutput delete cluster
  
  assertEquals \
    "Run with 'mokctl delete cluster' should fail with correct output" \
    "Please provide the Cluster NAME to delete." "${LINES[0]}"   
}

# ---------------------------------------------------------------------------
testNotEnoughOptionsToDeleteClusterName() {
# ---------------------------------------------------------------------------

  main create delete mycluster >/dev/null
  assertTrue \
    "'delete cluster mycluster' should fail" \
    "[[ $? -ge 1 ]]"
}

# ---------------------------------------------------------------------------
testNotEnoughOptionsToDeleteClusterNameOutput() {
# ---------------------------------------------------------------------------

  grabMainOutput delete mycluster mycluster
  
  assertEquals \
    "'delete cluster mycluster' should fail with correct output" \
    "Invalid SUBCOMMAND for delete, 'mycluster'." \
    "${LINES[0]}"
}

# ---------------------------------------------------------------------------
testValidDeleteClusterCommand() {
# ---------------------------------------------------------------------------

  # Check that all the create cluster vars are set

  do_delete_cluster_mutate(){ :; }

  parse_options delete cluster mycluster
  assertEquals \
    "Valid command: 'mokctl delete cluster mycluster'" \
    "$DELETE_CLUSTER_NAME" "mycluster"
}

# ===========================================================================
# shUnit2 funcs
# ===========================================================================

# ---------------------------------------------------------------------------
setUp() {
# ---------------------------------------------------------------------------
# source mokctl.deploy and disable output of usage().

  . ./mokctl.deploy
  usage() { :; }
}

# ---------------------------------------------------------------------------
tearDown(){
# ---------------------------------------------------------------------------
  rm -rf /var/tmp/mokctl-unit-tests.*
  cleanup
}

# ---------------------------------------------------------------------------
grabMainOutput() {
# ---------------------------------------------------------------------------
# Helper function. Sets LINES array to script output.

  local tmpname=`mktemp --tmpdir=/var/tmp mokctl-unit-tests.XXXXXXXX`
  main "$@" >$tmpname
  readarray -t LINES <$tmpname
}

# Load and run shUnit2.
. tests/shunit2

# vim:ft=bash:sw=2:et:ts=2: