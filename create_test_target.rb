require 'xcodeproj'
project = Xcodeproj::Project.open('/Users/madhumidha/Downloads/Projects/Forge/Forge.xcodeproj')

# Bail if already added (idempotency)
if project.targets.any? { |t| t.name == 'ForgeUtilitiesTests' }
  puts "ForgeUtilitiesTests target already exists with UUID #{project.targets.find { |t| t.name == 'ForgeUtilitiesTests' }.uuid}; nothing to do."
  exit 0
end

# Find the existing product dependency
product_dep = project.objects.find { |o|
  o.isa == 'XCSwiftPackageProductDependency' && o.product_name == 'ForgeUtilitiesTests'
}
raise 'XCSwiftPackageProductDependency not found' unless product_dep

begin
  # Prefer high-level API
  target = project.new_target(:unit_test_bundle, 'ForgeUtilitiesTests', :osx, '14.0', project.products_group, :swift)
  puts "new_target succeeded; UUID #{target.uuid}"
rescue => e
  puts "new_target failed: #{e.class}: #{e.message}"
  exit 1
end

project.save
puts "Saved"
