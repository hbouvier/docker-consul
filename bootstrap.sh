NAME=swarm-kvstore-001
ENCRYPTION_KEY=$(docker $(docker-machine config ${NAME}) run --rm -t consul:v0.6.4 keygen | tr -d '\n\r')

if [ -r etc/consul.d/ssl/encryption.key ] ; then
	ENCRYPTION_KEY=$(cat etc/consul.d/ssl/encryption.key)
else
	printf "${ENCRYPTION_KEY}" > etc/consul.d/ssl/encryption.key
fi

cat <<EOF >etc/consul.d/secured.conf
{
    "encrypt": "${ENCRYPTION_KEY}",
    "ca_file": "/consul/config/ssl/ca.cert",
    "cert_file": "/consul/config/ssl/consul.cert",
    "key_file": "/consul/config/ssl/consul.key",
    "verify_incoming": true,
    "verify_outgoing": true,
	"addresses": {
    	"https": "0.0.0.0"
  	},
  	"ports": {
    	"http": 8500,
    	"https": 8543
  	}
}
EOF

nodes=0
for NAME in swarm-kvstore-001 swarm-kvstore-002 ; do
nodes=$(expr $nodes + 1)
docker $(docker-machine config ${NAME}) inspect ${NAME}-data >& /dev/null || \
	docker $(docker-machine config ${NAME}) run -d --name ${NAME}-data -v /consul/data -v /consul/config busybox /bin/sh -c 'mkdir -p /consul/config /consul/data && chmod -R 777 /consul && while [ 1 ] ; do sleep 86400 ; done'

docker $(docker-machine config ${NAME}) run --rm -t -v `pwd`/etc:/backup --volumes-from ${NAME}-data busybox sh -c 'mkdir -p /consul/config/ssl ; cp /backup/consul.d/ssl/* /consul/config/ssl ; cp /backup/consul.d/secured.conf /consul/config/'

docker $(docker-machine config ${NAME}) run --name ${NAME} -d -h consul \
	--net=host --volumes-from ${NAME}-data \
	consul:v0.6.4 agent -server -bind 0.0.0.0 -client 0.0.0.0 \
	-advertise $(docker-machine ip ${NAME}) -node ${NAME}  \
	-dc dc1 -data-dir /consul/data -config-dir /consul/config \
	-config-file /consul/config/secured.conf \
	--bootstrap-expect ${nodes} -ui

if [ $nodes != 1 ] ; then
	echo joining ${MASTER}
	docker $(docker-machine config ${NAME}) exec -it ${NAME} consul join  $(docker-machine ip ${MASTER})
else
	MASTER=${NAME}
fi
done

docker $(docker-machine config ${MASTER}) exec -ti ${MASTER} consul members
