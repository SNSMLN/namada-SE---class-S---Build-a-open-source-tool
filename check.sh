#!/bin/bash

source $HOME/.bash_profile

BOT_TOKEN='****'
CHANNEL_ID="-1******"

MIN_BLOCK_INC=6
MIN_PEERS=15
MISSED_BLOCKS_MAX=10
MISSED_BLOCKS_DELTA_MAX=2
MAX_TIME=5


function message_send() {

    echo "Send message #$MESSAGE_TEXT# to TG" ;

    curl -s -X POST https://api.telegram.org/bot$BOT_TOKEN/sendMessage \
    -d chat_id=$CHANNEL_ID \
    -d parse_mode="Markdown" \
    -d text="$MESSAGE_TEXT" ;
} ##message_send



function message_send_save_prev_state() {
STATUS="$1"
STATUS_OK="$2"
PREV_STATE_FILE=$3
TEXT_ALARM=$4
TEXT_OK=$5

##
if [ ! -f $PREV_STATE_FILE ]; then echo "0" > $PREV_STATE_FILE; fi

if [[ "$STATUS" != "$STATUS_OK" ]]; then
    if [[ `cat $PREV_STATE_FILE` == "0" ]]; then
	MESSAGE_TEXT=$TEXT_ALARM ;
	message_send ;
        echo 1 > $PREV_STATE_FILE ;
    fi
    else 
        if [[ `cat $PREV_STATE_FILE` == "1" ]]; then
	    MESSAGE_TEXT=$TEXT_OK ;
            message_send ;
            echo 0 > $PREV_STATE_FILE ;
        fi
fi

} #function message_send_save_prev_state


##
cd $HOME/auto

##
DAEMON_STATUS=`/usr/bin/timeout $MAX_TIME systemctl status $DAEMON |grep Active | awk '{print $2}'`
VERSION=`/usr/bin/timeout $MAX_TIME $BIN_DIR/$BIN --version `
BLOCK_HEIGHT=`/usr/bin/timeout $MAX_TIME curl --max-time $MAX_TIME -s http://localhost:$RPC_PORT/status 2> /dev/null | jq .result.sync_info.latest_block_height | xargs`
PEERS=`/usr/bin/timeout $MAX_TIME curl --max-time $MAX_TIME -s http://localhost:$RPC_PORT/net_info | jq -r '.result.n_peers' `
VOTING_POWER=`/usr/bin/timeout $MAX_TIME curl --max-time $MAX_TIME -s http://localhost:$RPC_PORT/status  2> /dev/null  | jq .result.validator_info.voting_power | xargs`
POSITION=`/usr/bin/timeout $MAX_TIME namada client bonded-stake --node $NODE | grep -v -e "Last committed epoch:" -e "Consensus validators:" | cat -n | grep $VALIDATOR_ADDRESS | awk '{print $1}' `
STATUS_CURRENT=`/usr/bin/timeout $MAX_TIME namadac validator-state --validator $VALIDATOR_ADDRESS --node $NODE | sed "s/Validator $VALIDATOR_ADDRESS//"`

VALIDATOR_ADDRESS_HASH=$(/usr/bin/timeout $MAX_TIME curl --max-time $MAX_TIME -s localhost:26657/status | jq -r .result.validator_info.address)
MISSED_BLOCKS=0
for (( i=$BLOCK_HEIGHT; i>$BLOCK_HEIGHT-50 ; i-- )); do
    signatures=`/usr/bin/timeout $MAX_TIME curl -s "http://localhost:$RPC_PORT/block?height=${i}" | jq -r '.result.block.last_commit.signatures[].validator_address' `
    if ! echo "$signatures" | grep -q $VALIDATOR_ADDRESS_HASH; then
      MISSED_BLOCKS=$((MISSED_BLOCKS+1))
    fi
done


##Calculate current block hight increase
##BLOCK_HEIGHT=56179
PREVIOUS_HEIGHT=`cat state-height.txt`
BLOCK_INC=`echo " $BLOCK_HEIGHT - $PREVIOUS_HEIGHT " |bc -l`
CALC_BLOCK_INC=`echo " $BLOCK_HEIGHT - $PREVIOUS_HEIGHT <= $MIN_BLOCK_INC " |bc -l`

echo CALC_BLOCK_INC: $CALC_BLOCK_INC ;
##SAVE CURRENT Block
echo $BLOCK_HEIGHT>state-height.txt


##
##PEERS=5
CALC_MIN_PEERS=`echo "$PEERS <= $MIN_PEERS " |bc -l`
echo
echo CALC_MIN_PEERS: $CALC_MIN_PEERS ;

##
##MISSED_BLOCKS=10
FILE=state-missed-blocks.txt
MISSED_BLOCKS_PREVIOUS=`cat $FILE`
MISSED_BLOCKS_DELTA=`echo "$MISSED_BLOCKS - $MISSED_BLOCKS_PREVIOUS " |bc -l`
echo MISSED_BLOCKS_DELTA $MISSED_BLOCKS_DELTA
echo $MISSED_BLOCKS > $FILE

CALC_MISSED_BLOCKS_DELTA=`echo "$MISSED_BLOCKS_DELTA > $MISSED_BLOCKS_DELTA_MAX " |bc -l`
echo CALC_MISSED_BLOCKS_DELTA $CALC_MISSED_BLOCKS_DELTA ;

if [[ $CALC_MISSED_BLOCKS_DELTA != 0 ]] ;
then
	MESSAGE_TEXT="⚠ Alarm! Number of MISSED blocks increased per period 1 min more then $MISSED_BLOCKS_DELTA_MAX! Current value $MISSED_BLOCKS"
	message_send ;
fi

CALC_MISSED_BLOCKS=`echo "$MISSED_BLOCKS > $MISSED_BLOCKS_MAX " |bc -l`
echo
echo CALC_MISSED_BLOCKS: $CALC_MISSED_BLOCKS ;

message_send_save_prev_state \
$CALC_MISSED_BLOCKS  \
"0" \
"state-calc-MISSED-blocks.txt" \
"⚠ Alarm! Number of MISSED blocks more then $MISSED_BLOCKS_MAX! Current value $MISSED_BLOCKS" \
"✅Ok! Number of MISSED blocks less then $MISSED_BLOCKS_MAX! Current value $MISSED_BLOCKS" ;


##Calculate voting power change
##VOTING_POWER=100000000
VOTING_POWER_PREVIOUS=`cat state-voting-power.txt`
VOTING_POWER_CHANGE=`echo " $VOTING_POWER - $VOTING_POWER_PREVIOUS " |bc -l`
CALC_VOTING_POWER_CHANGE=`echo " $VOTING_POWER != $VOTING_POWER_PREVIOUS " |bc -l`
echo CALC_VOTING_POWER_CHANGE: $CALC_VOTING_POWER_CHANGE ;
##SAVE CURRENT power
echo $VOTING_POWER>state-voting-power.txt

if [[ $CALC_VOTING_POWER_CHANGE != 0 ]] ;
then
        MESSAGE_TEXT="⚡Atention! Voting power changed at $VOTING_POWER_CHANGE! Current value $VOTING_POWER" ;
        message_send ;
fi

## test STATUS_CURRENT is in the consensus set | is jailed
#STATUS_CURRENT=" is jailed"
message_send_save_prev_state \
"$STATUS_CURRENT" \
" is in the consensus set" \
"state-status-current.txt" \
"⚠ Alarm! Validator not in consensus" \
"✅Ok! Validator in consensus" ;


## test DAEMON_STATUS active | inactive
#DAEMON_STATUS=inactive
message_send_save_prev_state \
$DAEMON_STATUS \
"active" \
"state-daemon-status.txt" \
"⚠ Alarm! Service not running" \
"✅Ok! Service running" ;


##test CALC_BLOCK_INC = 0 | 1
#CALC_BLOCK_INC=1
message_send_save_prev_state \
$CALC_BLOCK_INC \
"0" \
"state-block-height.txt" \
"⚠ Alarm! Block height slow up" \
"✅Ok! Block height normal up" ;


## test MIN PEERS 0 | 1
#CALC_MIN_PEERS=1
message_send_save_prev_state \
$CALC_MIN_PEERS \
"0" \
"state-peers-num.txt" \
"⚠ Alarm! Number of peers is low" \
"✅Ok! Number of peers is normal" ;



