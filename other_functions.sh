source options.sh


check_db_connection() {
    for ((i=1; i<=DB_RETRIES; i++)); do
        error_msg=$(PGPASSWORD="$DB_PASSWORD" psql -U "$DB_USER" -d "$DB_NAME" -h "$DB_HOST" -p "$DB_PORT" -c "SELECT 1;" 2>&1)

        if [[ $? -eq 0 ]]; then
            echo "Database connection successful."
            return 0
        fi

        echo "Database not available, retrying ($i/$DB_RETRIES)..."
        sleep "$DB_WAIT_TIME"
    done

    dialog --title "Database Error" --msgbox "Failed to connect to the database after $DB_RETRIES attempts.\nError: $error_msg" 10 50
    clear
    exit 1
}

inventory_generate() {

    # Проверяем подключение к базе данных
    check_db_connection

    # Получаем данные из базы данных
    HOSTS_DATA=$(psql -U "$DB_USER" -h "$DB_HOST" -d "$DB_NAME" -t -A -c "
        SELECT devicename, ipaddress, username, port, connectiontype
        FROM NetworkDevices;")

    if [ -z "$HOSTS_DATA" ]; then
        echo "No hosts found in database to generate inventory!" >&2
        return
    fi

    # Генерируем файл инвентаря
    echo "[network_devices]" > "$INVENTORY_FILE"
    while IFS='|' read -r DEVICENAME IPADDRESS USERNAME PORT CONNECTION_TYPE; do
        if [ "$CONNECTION_TYPE" = "CiscoIOS" ]; then
            echo "$DEVICENAME ansible_host=$IPADDRESS ansible_user=$USERNAME ansible_connection=network_cli ansible_port=$PORT ansible_network_os=ios" >> "$INVENTORY_FILE"
        elif [ "$CONNECTION_TYPE" = "RouterOS" ]; then
            echo "$DEVICENAME ansible_host=$IPADDRESS ansible_user=$USERNAME ansible_connection=network_cli ansible_port=$PORT ansible_network_os=routeros" >> "$INVENTORY_FILE"
        fi
    done <<< "$HOSTS_DATA"

    echo "Ansible inventory file generated successfully at $INVENTORY_FILE"
}