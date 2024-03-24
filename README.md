# namada-SE---class-S---Build-a-open-source-tool

I did a simple monitoring of the node's state. Using a bash script. The script controls the main states of the node. And sends an alert to Telegram.
The following conditions are controlled:
- systemd service status
- binary version
- block height
- number of peers
- voting power
- position in the active set of validators
- validator status
- number of missed blocks


An example of messages sent in Telegram. The screenshot shows one of the updates during the testnet. But in general, the meaning of what the bot is doing should be clear

![namada bot](https://github.com/SNSMLN/namada-SE---class-S---Build-a-open-source-tool/assets/76874974/d868840e-3773-4f88-b368-7cca39e66d40)


The state after sending the alert is remembered. And a new alert is sent only after the state changes.


To do the same, you need to create a channel in Telegram. A channel can be created with any name.
Create a bot in Telegram, as written here https://core.telegram.org/bots#6-botfather
Add our bot to the channel and get the channel ID, as written here https://gist.github.com/dideler/85de4d64f66c1966788c1b2304b9caf1

Download the check.sh script from this repository https://github.com/SNSMLN/namada-SE---class-S---Build-a-open-source-tool/blob/main/check.sh. Place it in any convenient place on the server. My folder is /root/auto/
Inside the check.sh script, change the BOT_TOKEN and CHANNEL_ID variables.
After that, add the check.sh script to crontab. I call every 2 minutes. To avoid accidentally running two copies of the script. Since the script runs for almost 1 minute.


*/2 * * * * root /root/auto/check.sh
