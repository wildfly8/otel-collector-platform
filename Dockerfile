FROM otel/opentelemetry-collector-contrib:0.156.0

COPY collector/config.yaml /etc/otelcol-contrib/config.yaml

EXPOSE 4318 13133 8888

ENTRYPOINT ["/otelcol-contrib"]
CMD ["--config=/etc/otelcol-contrib/config.yaml"]

