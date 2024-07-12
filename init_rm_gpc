#!/bin/bash

# Script để xóa tất cả các project và vô hiệu hóa billing của tất cả các project trong Google Cloud
# Lấy danh sách tất cả các tài khoản billing
billing_accounts=$(gcloud beta billing accounts list --format="value(name)")
# Vô hiệu hóa billing cho tất cả các project
echo "Bắt đầu vô hiệu hóa billing cho tất cả các project..."
for account in $billing_accounts; do
    for project in $(gcloud beta billing projects list --billing-account="$account" --format="value(projectId)"); do
        echo "Vô hiệu hóa billing cho project: $project"
        gcloud beta billing projects unlink "$project"
    done
done
echo "Hoàn thành việc vô hiệu hóa billing."
# Xóa tất cả các project
echo "Bắt đầu xóa tất cả các project..."
for project in $(gcloud projects list --format="value(projectId)"); do
    echo "Đang xóa project: $project"
    gcloud projects delete "$project" --quiet
done
echo "Hoàn thành việc xóa tất cả các project."
echo "Tất cả các project đã được xóa và billing đã được vô hiệu hóa."
