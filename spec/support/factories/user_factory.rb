FactoryGirl.define do
  factory :user do
    role_id         123
    first_name      "Uni"
    last_name       "Corn"
    access_level    "viewable"
  end
end
