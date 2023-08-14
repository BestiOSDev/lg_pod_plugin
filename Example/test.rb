require 'json'
require 'fileutils'
# FileUtils.rm_rf("./Pods")
# FileUtils.rm_rf("./Podfile.lock")
# FileUtils.rm_rf "/Users/dongzb01/Library/Caches/CocoaPods/Pods/External/LCombineExtension"
# FileUtils.rm_rf "/Users/dongzb01/Library/Caches/CocoaPods/Pods/Specs/External/LCombineExtension"
# FileUtils.rm_rf "/Users/dongzb01/Library/Caches/CocoaPods/Pods/Release"
# FileUtils.rm_rf "/Users/dongzb01/Library/Caches/CocoaPods/Pods/Specs/Release"
begin_time = Time.now.to_i
system("bundle exec lg update")
end_time = Time.now.to_i
puts end_time - begin_time
