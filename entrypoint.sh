#!/bin/sh
# Based on https://raw.githubusercontent.com/brainsam/pgbouncer/master/entrypoint.sh

set -e

# Here are some parameters. See all on
# https://pgbouncer.github.io/config.html

PG_CONFIG_DIR=/etc/pgbouncer

if [ -n "$DATABASE_URL" ]; then
  # Thanks to https://stackoverflow.com/a/17287984/146289

  # Allow to pass values like dj-database-url / django-environ accept
  proto="$(echo $DATABASE_URL | grep :// | sed -e's,^\(.*://\).*,\1,g')"
  url="$(echo $DATABASE_URL | sed -e s,$proto,,g)"

  # extract the user and password (if any)
  userpass=$(echo $url | grep @ | sed -r 's/^(.*)@([^@]*)$/\1/')
  DATABASES_PASSWORD="$(echo $userpass | grep : | cut -d: -f2)"
  if [ -n "$DATABASES_PASSWORD" ]; then
    DATABASES_USER=$(echo $userpass | grep : | cut -d: -f1)
  else
    DATABASES_USER=$userpass
  fi

  # extract the host -- updated
  hostport=$(echo $url | sed -e s,$userpass@,,g | cut -d/ -f1)
  port=$(echo $hostport | grep : | cut -d: -f2)
  if [ -n "$port" ]; then
      DATABASES_HOST=$(echo $hostport | grep : | cut -d: -f1)
      DATABASES_PORT=$port
  else
      DATABASES_HOST=$hostport
  fi

  DATABASES_NAME="$(echo $url | grep / | cut -d/ -f2-)"
fi

# Write the password with MD5 encryption, to avoid printing it during startup.
# Notice that `docker inspect` will show unencrypted env variables.
_PGBOUNCER_AUTH_FILE="${PGBOUNCER_AUTH_FILE:-$PG_CONFIG_DIR/userlist.txt}"

# Workaround userlist.txt missing issue
# https://github.com/edoburu/docker-pgbouncer/issues/33
if [ ! -e "${_PGBOUNCER_AUTH_FILE}" ]; then
  touch "${_PGBOUNCER_AUTH_FILE}"
fi

if [ -n "$DATABASES_USER" -a -n "$DATABASES_PASSWORD" -a -e "${_PGBOUNCER_AUTH_FILE}" ] && ! grep -q "^\"$DATABASES_USER\"" "${_PGBOUNCER_AUTH_FILE}"; then
  if [ "$PGBOUNCER_AUTH_TYPE" != "plain" ]; then
     pass="md5$(echo -n "$DATABASES_PASSWORD$DATABASES_USER" | md5sum | cut -f 1 -d ' ')"
  else
     pass="$DATABASES_PASSWORD"
  fi
  echo "\"$DATABASES_USER\" \"$pass\"" >> ${PG_CONFIG_DIR}/userlist.txt
  echo "Wrote authentication credentials to ${PG_CONFIG_DIR}/userlist.txt"
fi

if [ ! -f ${PG_CONFIG_DIR}/pgbouncer.ini ]; then
  echo "Create pgbouncer config in ${PG_CONFIG_DIR}"

# Config file is in “ini” format. Section names are between “[” and “]”.
# Lines starting with “;” or “#” are taken as comments and ignored.
# The characters “;” and “#” are not recognized when they appear later in the line.
  printf "\
################## Auto generated ##################
[databases]
${DATABASES_NAME:-*} = host=${DATABASES_HOST:?"Setup pgbouncer config error! You must set DATABASES_HOST env"} \
port=${DATABASES_PORT:-5432} \
dbname=${DATABASES_DBNAME:-postgres} \
auth_user=${DATABASES_AUTH_USER:?"Must define an auth_user for the SWOPS setup"} \
timezone=${DATABASES_TIMEZONE:-utc}
${DATABASES_CLIENT_ENCODING:+client_encoding = ${DATABASES_CLIENT_ENCODING}\n}\


[pgbouncer]
listen_addr = ${PGBOUNCER_LISTEN_ADDR:-0.0.0.0}
listen_port = ${PGBOUNCER_LISTEN_PORT:-5432}
auth_file = ${PGBOUNCER_AUTH_FILE:-$PG_CONFIG_DIR/userlist.txt}
${PGBOUNCER_AUTH_HBA_FILE:+auth_hba_file = ${PGBOUNCER_AUTH_HBA_FILE}\n}\
auth_type = ${PGBOUNCER_AUTH_TYPE:-md5}
${PGBOUNCER_AUTH_USER:+auth_user = ${PGBOUNCER_AUTH_USER}\n}\
${PGBOUNCER_AUTH_QUERY:+auth_query = ${PGBOUNCER_AUTH_QUERY}\n}\
${PGBOUNCER_POOL_MODE:+pool_mode = ${PGBOUNCER_POOL_MODE}\n}\
${PGBOUNCER_MAX_CLIENT_CONN:+max_client_conn = ${PGBOUNCER_MAX_CLIENT_CONN}\n}\
${PGBOUNCER_DEFAULT_POOL_SIZE:+default_pool_size = ${PGBOUNCER_DEFAULT_POOL_SIZE}\n}\
${PGBOUNCER_MIN_POOL_SIZE:+min_pool_size = ${PGBOUNCER_MIN_POOL_SIZE}\n}\
${PGBOUNCER_RESERVE_POOL_SIZE:+reserve_pool_size = ${PGBOUNCER_RESERVE_POOL_SIZE}\n}\
${PGBOUNCER_RESERVE_POOL_TIMEOUT:+reserve_pool_timeout = ${PGBOUNCER_RESERVE_POOL_TIMEOUT}\n}\
${PGBOUNCER_MAX_DB_CONNECTIONS:+max_db_connections = ${PGBOUNCER_MAX_DB_CONNECTIONS}\n}\
${PGBOUNCER_MAX_USER_CONNECTIONS:+max_user_connections = ${PGBOUNCER_MAX_USER_CONNECTIONS}\n}\
${PGBOUNCER_SERVER_ROUND_ROBIN:+server_round_robin = ${PGBOUNCER_SERVER_ROUND_ROBIN}\n}\
ignore_startup_parameters = ${PGBOUNCER_IGNORE_STARTUP_PARAMETERS:-extra_float_digits}
${PGBOUNCER_DISABLE_PQEXEC:+disable_pqexec = ${PGBOUNCER_DISABLE_PQEXEC}\n}\
${PGBOUNCER_APPLICATION_NAME_ADD_HOST:+application_name_add_host = ${PGBOUNCER_APPLICATION_NAME_ADD_HOST}\n}\

# Log settings
${PGBOUNCER_LOG_CONNECTIONS:+log_connections = ${PGBOUNCER_LOG_CONNECTIONS}\n}\
${PGBOUNCER_LOG_DISCONNECTIONS:+log_disconnections = ${PGBOUNCER_LOG_DISCONNECTIONS}\n}\
${PGBOUNCER_LOG_POOLER_ERRORS:+log_pooler_errors = ${PGBOUNCER_LOG_POOLER_ERRORS}\n}\
${PGBOUNCER_LOG_STATS:+log_stats = ${PGBOUNCER_LOG_STATS}\n}\
${PGBOUNCER_STATS_PERIOD:+stats_period = ${PGBOUNCER_STATS_PERIOD}\n}\
${PGBOUNCER_VERBOSE:+verbose = ${PGBOUNCER_VERBOSE}\n}\
admin_users = ${PGBOUNCER_ADMIN_USERS:-postgres}
${PGBOUNCER_STATS_USERS:+stats_users = ${PGBOUNCER_STATS_USERS}\n}\

# Connection sanity checks, timeouts
${PGBOUNCER_SERVER_RESET_QUERY:+server_reset_query = ${PGBOUNCER_SERVER_RESET_QUERY}\n}\
${PGBOUNCER_SERVER_RESET_QUERY_ALWAYS:+server_reset_query_always = ${PGBOUNCER_SERVER_RESET_QUERY_ALWAYS}\n}\
${PGBOUNCER_SERVER_CHECK_DELAY:+server_check_delay = ${PGBOUNCER_SERVER_CHECK_DELAY}\n}\
${PGBOUNCER_SERVER_CHECK_QUERY:+server_check_query = ${PGBOUNCER_SERVER_CHECK_QUERY}\n}\
${PGBOUNCER_SERVER_LIFETIME:+server_lifetime = ${PGBOUNCER_SERVER_LIFETIME}\n}\
${PGBOUNCER_SERVER_IDLE_TIMEOUT:+server_idle_timeout = ${PGBOUNCER_SERVER_IDLE_TIMEOUT}\n}\
${PGBOUNCER_SERVER_CONNECT_TIMEOUT:+server_connect_timeout = ${PGBOUNCER_SERVER_CONNECT_TIMEOUT}\n}\
${PGBOUNCER_SERVER_LOGIN_RETRY:+server_login_retry = ${PGBOUNCER_SERVER_LOGIN_RETRY}\n}\
${PGBOUNCER_CLIENT_LOGIN_TIMEOUT:+client_login_timeout = ${PGBOUNCER_CLIENT_LOGIN_TIMEOUT}\n}\
${PGBOUNCER_AUTODB_IDLE_TIMEOUT:+autodb_idle_timeout = ${PGBOUNCER_AUTODB_IDLE_TIMEOUT}\n}\
${PGBOUNCER_DNS_MAX_TTL:+dns_max_ttl = ${PGBOUNCER_DNS_MAX_TTL}\n}\
${PGBOUNCER_DNS_NXDOMAIN_TTL:+dns_nxdomain_ttl = ${PGBOUNCER_DNS_NXDOMAIN_TTL}\n}\

# TLS settings
${PGBOUNCER_CLIENT_TLS_SSLMODE:+client_tls_sslmode = ${PGBOUNCER_CLIENT_TLS_SSLMODE}\n}\
${PGBOUNCER_CLIENT_TLS_KEY_FILE:+client_tls_key_file = ${PGBOUNCER_CLIENT_TLS_KEY_FILE}\n}\
${PGBOUNCER_CLIENT_TLS_CERT_FILE:+client_tls_cert_file = ${PGBOUNCER_CLIENT_TLS_CERT_FILE}\n}\
${PGBOUNCER_CLIENT_TLS_CA_FILE:+client_tls_ca_file = ${PGBOUNCER_CLIENT_TLS_CA_FILE}\n}\
${PGBOUNCER_CLIENT_TLS_PROTOCOLS:+client_tls_protocols = ${PGBOUNCER_CLIENT_TLS_PROTOCOLS}\n}\
${PGBOUNCER_CLIENT_TLS_CIPHERS:+client_tls_ciphers = ${PGBOUNCER_CLIENT_TLS_CIPHERS}\n}\
${PGBOUNCER_CLIENT_TLS_ECDHCURVE:+client_tls_ecdhcurve = ${PGBOUNCER_CLIENT_TLS_ECDHCURVE}\n}\
${PGBOUNCER_CLIENT_TLS_DHEPARAMS:+client_tls_dheparams = ${PGBOUNCER_CLIENT_TLS_DHEPARAMS}\n}\
${PGBOUNCER_SERVER_TLS_SSLMODE:+server_tls_sslmode = ${PGBOUNCER_SERVER_TLS_SSLMODE}\n}\
${PGBOUNCER_SERVER_TLS_CA_FILE:+server_tls_ca_file = ${PGBOUNCER_SERVER_TLS_CA_FILE}\n}\
${PGBOUNCER_SERVER_TLS_KEY_FILE:+server_tls_key_file = ${PGBOUNCER_SERVER_TLS_KEY_FILE}\n}\
${PGBOUNCER_SERVER_TLS_CERT_FILE:+server_tls_cert_file = ${PGBOUNCER_SERVER_TLS_CERT_FILE}\n}\
${PGBOUNCER_SERVER_TLS_PROTOCOLS:+server_tls_protocols = ${PGBOUNCER_SERVER_TLS_PROTOCOLS}\n}\
${PGBOUNCER_SERVER_TLS_CIPHERS:+server_tls_ciphers = ${PGBOUNCER_SERVER_TLS_CIPHERS}\n}\

# Dangerous timeouts
${PGBOUNCER_QUERY_TIMEOUT:+query_timeout = ${PGBOUNCER_QUERY_TIMEOUT}\n}\
${PGBOUNCER_QUERY_WAIT_TIMEOUT:+query_wait_timeout = ${PGBOUNCER_QUERY_WAIT_TIMEOUT}\n}\
${PGBOUNCER_CLIENT_IDLE_TIMEOUT:+client_idle_timeout = ${PGBOUNCER_CLIENT_IDLE_TIMEOUT}\n}\
${PGBOUNCER_IDLE_TRANSACTION_TIMEOUT:+idle_transaction_timeout = ${PGBOUNCER_IDLE_TRANSACTION_TIMEOUT}\n}\
${PGBOUNCER_PKT_BUF:+pkt_buf = ${PGBOUNCER_PKT_BUF}\n}\
${PGBOUNCER_MAX_PACKET_SIZE:+max_packet_size = ${PGBOUNCER_MAX_PACKET_SIZE}\n}\
${PGBOUNCER_LISTEN_BACKLOG:+listen_backlog = ${PGBOUNCER_LISTEN_BACKLOG}\n}\
${PGBOUNCER_SBUF_LOOPCNT:+sbuf_loopcnt = ${PGBOUNCER_SBUF_LOOPCNT}\n}\
${PGBOUNCER_SUSPEND_TIMEOUT:+suspend_timeout = ${PGBOUNCER_SUSPEND_TIMEOUT}\n}\
${PGBOUNCER_TCP_DEFER_ACCEPT:+tcp_defer_accept = ${PGBOUNCER_TCP_DEFER_ACCEPT}\n}\
${PGBOUNCER_TCP_KEEPALIVE:+tcp_keepalive = ${PGBOUNCER_TCP_KEEPALIVE}\n}\
${PGBOUNCER_TCP_KEEPCNT:+tcp_keepcnt = ${PGBOUNCER_TCP_KEEPCNT}\n}\
${PGBOUNCER_TCP_KEEPIDLE:+tcp_keepidle = ${PGBOUNCER_TCP_KEEPIDLE}\n}\
${PGBOUNCER_TCP_KEEPINTVL:+tcp_keepintvl = ${PGBOUNCER_TCP_KEEPINTVL}\n}\
${PGBOUNCER_TCP_USER_TIMEOUT:+tcp_user_timeout = ${PGBOUNCER_TCP_USER_TIMEOUT}\n}\
################## end file ##################
" > ${PG_CONFIG_DIR}/pgbouncer.ini
cat ${PG_CONFIG_DIR}/pgbouncer.ini
echo "Starting $*..."
fi

# Start the inotify loop for pgbouncer to reload if the cert changes
while true; do
  inotifywait -e modify ${PGBOUNCER_CLIENT_TLS_KEY_FILE} ${PGBOUNCER_CLIENT_TLS_CERT_FILE} ${PGBOUNCER_CLIENT_TLS_CA_FILE} || {
    echo "inotifywait failed with exit code $?"
    exit 1
  }
  pkill -HUP pgbouncer
done &

exec "$@"
