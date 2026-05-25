FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       bash \
       ca-certificates \
       curl \
       gcc \
       libc6-dev \
       make \
       netcat-openbsd \
       stress-ng \
      
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY pmic_raw_logger.c /app/pmic_raw_logger.c
COPY run_with_logging.c /app/run_with_logging.c
COPY energylogger.sh /app/energylogger.sh
COPY sigmark.sh /app/sigmark.sh

RUN gcc -O2 -Wall -Wextra -o /app/pmic_raw_logger /app/pmic_raw_logger.c -lm \
    && gcc -O2 -Wall -Wextra -o /app/run_with_logging /app/run_with_logging.c \
    && chmod +x /app/energylogger.sh /app/sigmark.sh /app/pmic_raw_logger /app/run_with_logging

VOLUME ["/data"]

CMD ["/app/energylogger.sh"]
