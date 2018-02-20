FactoryGirl.define do
  factory :user do
    role_id         123

    sequence :first_name do |n| "First #{n}" end
    sequence :last_name  do |n| "Last #{n}"  end
    access_level    "viewable"
  end

  factory :unique_user do
    sequence :first_name do |n| "First #{n}" end
    sequence :last_name  do |n| "Last #{n}"  end
  end
end
