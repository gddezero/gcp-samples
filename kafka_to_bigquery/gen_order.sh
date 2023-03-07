$KAFKA_HOME/bin/kafka-topics.sh --create --topic orderbook --replication-factor 1 --partitions 1 --bootstrap-server localhost:9093
$KAFKA_HOME/bin/kafka-topics.sh --create --topic orderbook_okx --replication-factor 1 --partitions 1 --bootstrap-server localhost:9093

for x in {1..3600}
do
  echo '{"e":"depthUpdate","t":'$(date +%s)',"s":"BTCUSDT","i":'$(($x+2))',"l":'$x',"b":["'$(awk "BEGIN {x=$(shuf -i 1-100000 -n 1);y=10000;print x/y}")'","'$(shuf -i 1-100 -n 1)'"],"a":["'$(awk "BEGIN {x=$(shuf -i 1-100000 -n 1);y=10000;print x/y}")'","'$(shuf -i 1-100 -n 1)'"]}'
  sleep 1
done | $KAFKA_HOME/bin/kafka-console-producer.sh --broker-list localhost:9093 --topic orderbook