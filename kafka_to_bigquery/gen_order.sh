IP=$1
/opt/kafka/bin/kafka-topics.sh --bootstrap-server ${IP}:9092 --create --topic orderbook
/opt/kafka/bin/kafka-topics.sh --bootstrap-server ${IP}:9092 --create --topic orderbook_eth

for x in {1..3600}
do
  echo '{"e":"depthUpdate","t":'$(date +%s)',"s":"BTCUSDT","i":'$(($x+2))',"l":'$x',"b":["'$(awk "BEGIN {x=$(shuf -i 1-100000 -n 1);y=10000;print x/y}")'","'$(shuf -i 1-100 -n 1)'"],"a":["'$(awk "BEGIN {x=$(shuf -i 1-100000 -n 1);y=10000;print x/y}")'","'$(shuf -i 1-100 -n 1)'"]}'
  sleep 1
done | /opt/kafka/bin/kafka-console-producer.sh --bootstrap-server ${IP}:9092 --topic orderbook