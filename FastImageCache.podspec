Pod::Spec.new do |s|

  s.name         = "FastImageCache"
  s.version      = "1.2"
  s.summary      = "iOS library for quickly displaying images while scrolling"

  s.description  = <<-DESC
Fast Image Cache is an efficient, persistent, and—above all—fast way to store and retrieve images in your iOS application. Part of any good iOS application's user experience is fast, smooth scrolling, and Fast Image Cache helps make this easier.

A significant burden on performance for graphics-rich applications like Path is image loading. The traditional method of loading individual images from disk is just too slow, especially while scrolling. Fast Image Cache was created specifically to solve this problem.
                   DESC

  s.homepage     = "https://github.com/path/FastImageCache"
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.authors      = { "Mallory Paine" => "mallory@path.com", "Michael Potter" => "michael@path.com" }

  s.platform     = :ios
  s.platform     = :ios, '6.0'
  s.source       = { :git => "https://github.com/path/FastImageCache.git", :tag => "1.2" }

  s.source_files  = 'FastImageCache'
  s.requires_arc = true

end