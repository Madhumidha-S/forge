require 'xcodeproj'
project = Xcodeproj::Project.open('/Users/madhumidha/Downloads/Projects/Forge/Forge.xcodeproj')

target = project.targets.find { |t| t.name == 'ForgeUtilitiesTests' }
raise 'Target not found' unless target

product_dep = project.objects.find { |o|
  o.isa == 'XCSwiftPackageProductDependency' && o.product_name == 'ForgeUtilitiesTests'
}
raise 'Product dependency not found' unless product_dep

# Add package product dependency to target if missing
unless target.package_product_dependencies.include?(product_dep)
  target.package_product_dependencies << product_dep
end

# Add a PBXBuildFile in the test target's frameworks build phase
frameworks_phase = target.frameworks_build_phase
already = frameworks_phase.files.any? { |f| f.product_ref == product_dep }
unless already
  build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
  build_file.product_ref = product_dep
  frameworks_phase.files << build_file
end

# Add a target dependency pointing at the product dependency
unless target.dependencies.any? { |d| d.product_ref == product_dep }
  target_dep = project.new(Xcodeproj::Project::Object::PBXTargetDependency)
  target_dep.product_ref = product_dep
  target.dependencies << target_dep
end

project.save
puts "Updated target #{target.uuid}"
