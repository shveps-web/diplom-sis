
playbooks() {
    dialog --no-cancel --title "Playbooks" --msgbox "PLAYBOOKS \n\n [OK] - return to menu" 12 50
   
   
}

hosts() {
    # Получаем список хостов с порядковыми номерами
    MENU_ITEMS=$(psql -U "$DB_USER" -h "$DB_HOST" -d "$DB_NAME" -t -A -c "
        SELECT ROW_NUMBER() OVER (ORDER BY id) AS row_num, devicename
        FROM NetworkDevices;" | awk -F'|' '{print $1 " \"" $2 "\""}')

    if [ -z "$MENU_ITEMS" ]; then
        dialog --msgbox "No hosts found in database!" 10 40
        return
    fi

    # Выбор хоста из списка
    HOST_CHOICE=$(dialog --title "Hosts" --menu "Select a host:" 15 50 6 ${MENU_ITEMS} 3>&1 1>&2 2>&3)

    if [ -n "$HOST_CHOICE" ]; then
        # Получаем информацию о выбранном хосте по порядковому номеру
        HOST_INFO=$(psql -U "$DB_USER" -h "$DB_HOST" -d "$DB_NAME" -t -A -c "
            SELECT devicename, ipaddress, username, port, connectiontype
            FROM (
                SELECT ROW_NUMBER() OVER (ORDER BY id) AS row_num, *
                FROM NetworkDevices
            ) subquery
            WHERE row_num = $HOST_CHOICE;")
        DEVICE_NAME=$(echo "$HOST_INFO" | awk -F'|' '{print $1}')
        IP_ADDRESS=$(echo "$HOST_INFO" | awk -F'|' '{print $2}')
        USERNAME=$(echo "$HOST_INFO" | awk -F'|' '{print $3}')
        PORT=$(echo "$HOST_INFO" | awk -F'|' '{print $4}')
        CONNECTION_TYPE=$(echo "$HOST_INFO" | awk -F'|' '{print $5}')

        # Формируем сообщение для отображения
        INFO_MESSAGE="Device Name: $DEVICE_NAME\n\n"
        INFO_MESSAGE+="IP Address: $IP_ADDRESS\n"
        INFO_MESSAGE+="User: $USERNAME\n"
        INFO_MESSAGE+="Port: $PORT\n"
        INFO_MESSAGE+="Connection Type: $CONNECTION_TYPE\n"

        dialog --title "$DEVICE_NAME" --msgbox "$INFO_MESSAGE" 15 50
    fi
}

add_host() {
    # Меню для выбора типа устройства
    CONNECTION_TYPE=$(dialog --title "Select Device Type" --menu "Choose the device type:" 15 50 2 \
        "RouterOS" "MikroTik RouterOS device" \
        "CiscoIOS" "Cisco IOS device" 3>&1 1>&2 2>&3)

    if [ $? -ne 0 ]; then
        return
    fi

    # Форма для ввода данных устройства
    FORM_DATA=$(dialog --title "Add New Host" --form "Enter host details:" 15 50 6 \
        "Device Name:" 1 1 "" 1 15 30 0 \
        "IP Address:" 2 1 "" 2 15 30 0 \
        "User:"       3 1 "" 3 15 30 0 \
        "Password:"   4 1 "" 4 15 30 0 \
        "Port (optional):" 5 1 "" 5 15 30 0 3>&1 1>&2 2>&3)

    if [ $? -ne 0 ]; then
        return
    fi

    DEVICENAME=$(echo "$FORM_DATA" | sed -n '1p')
    IPADDRESS=$(echo "$FORM_DATA" | sed -n '2p')
    USER=$(echo "$FORM_DATA" | sed -n '3p')
    PASSWORD=$(echo "$FORM_DATA" | sed -n '4p')
    PORT=$(echo "$FORM_DATA" | sed -n '5p')

    if [ -z "$DEVICENAME" ] || [ -z "$IPADDRESS" ] || [ -z "$USER" ] || [ -z "$PASSWORD" ]; then
        dialog --msgbox "All fields except Port are required!" 10 40
        return
    fi

    if [ -z "$PORT" ]; then
        INSERT_QUERY="INSERT INTO NetworkDevices (devicename, ipaddress, username, password, connectiontype) VALUES ('$DEVICENAME', '$IPADDRESS', '$USER', '$PASSWORD', '$CONNECTION_TYPE');"
    else
        INSERT_QUERY="INSERT INTO NetworkDevices (devicename, ipaddress, username, password, port, connectiontype) VALUES ('$DEVICENAME', '$IPADDRESS', '$USER', '$PASSWORD', $PORT, '$CONNECTION_TYPE');"
    fi

    psql -U "$DB_USER" -h "$DB_HOST" -d "$DB_NAME" -c "$INSERT_QUERY" 2>/tmp/db_error.log

    if [ $? -eq 0 ]; then
        dialog --msgbox "Host added successfully!" 10 40
    else
        ERROR_MSG=$(cat /tmp/db_error.log)
        dialog --msgbox "Failed to add host! Error: $ERROR_MSG" 10 50
    fi
    inventory_generate
}

del_host() {
    while true; do
        # Получаем список хостов с порядковыми номерами
        MENU_ITEMS=$(psql -U "$DB_USER" -h "$DB_HOST" -d "$DB_NAME" -t -A -c "
            SELECT ROW_NUMBER() OVER (ORDER BY id) AS row_num, devicename
            FROM NetworkDevices;" | awk -F'|' '{print $1 " \"" $2 "\""}')

        if [ -z "$MENU_ITEMS" ]; then
            dialog --msgbox "No hosts found in database!" 10 40
            return
        fi

        # Выбор хоста из списка
        HOST_CHOICE=$(dialog --title "Delete Host" --menu "Select a host to delete:" 15 50 6 ${MENU_ITEMS} 3>&1 1>&2 2>&3)

        if [ -z "$HOST_CHOICE" ]; then
          
            return
        fi

  
        dialog --yesno "Are you sure you want to delete this host?" 10 50
        if [ $? -eq 0 ]; then
        
            DELETE_QUERY="
            DELETE FROM NetworkDevices
            WHERE id = (
                SELECT id
                FROM (
                    SELECT ROW_NUMBER() OVER (ORDER BY id) AS row_num, id
                    FROM NetworkDevices
                ) subquery
                WHERE row_num = $HOST_CHOICE
            );"
            PGPASSWORD="$DB_PASSWORD" psql -U "$DB_USER" -h "$DB_HOST" -d "$DB_NAME" -c "$DELETE_QUERY" 2>/tmp/db_error.log

            if [ $? -eq 0 ]; then
                dialog --msgbox "Host deleted successfully!" 10 40
                inventory_generate
            else
                ERROR_MSG=$(cat /tmp/db_error.log)
                dialog --msgbox "Failed to delete host! Error: $ERROR_MSG" 10 50
            fi
        fi
    done
    
}

add_playbook() {
    dialog --no-cancel --title "ADD PLAYBOOK" --msgbox "ADD PLAYBOOK \n\n [OK] - return to menu" 12 50
    # Загрузить новый плейбук
}

del_playbook() {
    dialog --no-cancel --title "DEL PLAYBOOK" --msgbox "DEL PLAYBOOK \n\n [OK] - return to menu" 12 50
    # Удалить плейбук (Возможно перенести данное меню внутрь playbooks)
}

devices_info() {
    dialog --no-cancel --title "DEVICE INFO" --msgbox "DEVICE INFO \n\n [OK] - return to menu" 12 50
    # Меню с информацией о девайсах, тоже подтягивать из бд
}

collect_data() {
    
    PLAYBOOK_FILE="collect_data.yml"

    # Проверяем, существует ли файл инвентаря
    if [ ! -f "$INVENTORY_FILE" ]; then
        echo "Inventory file not found. Generating a new one..."
        inventory_generate
    fi

    # Проверяем, существует ли файл после генерации
    if [ ! -f "$INVENTORY_FILE" ]; then
        echo "Failed to generate inventory file. Exiting..." >&2
        return
    fi

    # Проверяем, существует ли playbook
    if [ ! -f "$PLAYBOOK_FILE" ]; then
        echo "Playbook file '$PLAYBOOK_FILE' not found. Exiting..." >&2
        return
    fi

    # Отображаем меню загрузки
    {
        echo "0"; sleep 1
        echo "# Starting Ansible playbook execution..."
        ansible-playbook -i "$INVENTORY_FILE" "$PLAYBOOK_FILE" > /tmp/ansible_output.log 2>&1
        if [ $? -ne 0 ]; then
            echo "100"
            echo "# Failed to collect device information. Check '/tmp/ansible_output.log' for details."
            sleep 2
            return
        fi
        echo "50"; sleep 1
        echo "# Processing collected data..."
        sleep 1
        echo "100"
    } | dialog --title "Collecting Data" --gauge "Please wait while data is being collected..." 10 50 0

    # Обрабатываем собранные данные
    if [ ! -f "device_data.txt" ]; then
        echo "Device data file 'device_data.txt' not found. Exiting..." >&2
        return
    fi

    while IFS='|' read -r DEVICE_NAME OS CPU RAM; do
        # Получаем ID устройства из таблицы NetworkDevices
        DEVICE_ID=$(psql -U "$DB_USER" -h "$DB_HOST" -d "$DB_NAME" -t -A -c "
            SELECT id FROM NetworkDevices WHERE devicename = '$DEVICE_NAME';")

        if [ -z "$DEVICE_ID" ]; then
            echo "Device '$DEVICE_NAME' not found in database. Skipping..." >&2
            continue
        fi

        # Вставляем или обновляем данные в таблице NetworkProperty
        psql -U "$DB_USER" -h "$DB_HOST" -d "$DB_NAME" -c "
            INSERT INTO NetworkProperty (networkdeviceid, os, cpu, ram)
            VALUES ($DEVICE_ID, '$OS', $CPU, $RAM)
            ON CONFLICT (networkdeviceid) DO UPDATE
            SET os = EXCLUDED.os, cpu = EXCLUDED.cpu, ram = EXCLUDED.ram;" 2>/tmp/db_error.log

        if [ $? -ne 0 ]; then
            echo "Failed to update database for device '$DEVICE_NAME'. Check '/tmp/db_error.log' for details." >&2
        else
            echo "Device '$DEVICE_NAME' information updated successfully."
        fi
    done < device_data.txt
}

management() {
    while true; do
     CHOICE=$(dialog --no-cancel --title "Management" --menu "Choose an option:" 15 50 6 \
            "1" "Add playbook" \
            "2" "Delete playbook" \
            "3" "Add host" \
            "4" "Delete host" \
            "5" "Device Info" \
            "6" "Collect data" \
            "7" "Exit to menu" 3>&1 1>&2 2>&3) 
        
        case $CHOICE in
            1) add_playbook ;;
            2) del_playbook ;;
            3) add_host ;;
            4) del_host ;;
            5) devices_info ;;
            6) collect_data ;;
            7) main_menu ;;
            *) dialog --no-cancel --msgbox "Invalid option!" 10 40 ;;

        esac
    done
}

main_menu() {
    while true; do
     CHOICE=$(dialog --no-cancel --title "Menu" --menu "Choose an option:" 15 50 6 \
            "1" "Playbooks" \
            "2" "Hosts" \
            "3" "Managment" \
            "4" "Exit" 3>&1 1>&2 2>&3) 
        
        case $CHOICE in
            1) playbooks ;;
            2) hosts ;;
            3) management ;;
            4) clear; exit 0 ;;
        esac
    done
}