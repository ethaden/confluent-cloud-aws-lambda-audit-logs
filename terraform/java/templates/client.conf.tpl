# Consume directly with this command:
# kafka-console-consumer --consumer.config client-${client_name}.conf --bootstrap-server ${cluster_bootstrap_server} --topic ${topic} --from-beginning

bootstrap.servers=${cluster_bootstrap_server}
security.protocol=SASL_SSL
sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username='${api_key}' password='${api_secret}';
sasl.mechanism=PLAIN
# Required for consumers only:
group.id=${client_name}
