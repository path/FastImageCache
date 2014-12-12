Pod::Spec.new do |s|
  s.name         = "FastImageCache"
  s.author       = { "Mallory Paine" => "mpaine@gmail.com" }
  s.version      = "1.3"
  s.summary      = "iOS library for quickly displaying images while scrolling"
  s.description  = "Fast Image Cache is an efficient, persistent, and—above all—fast way to store and retrieve images in your iOS application. Part of any good iOS application's user experience is fast, smooth scrolling, and Fast Image Cache helps make this easier.\n\nA significant burden on performance for graphics-rich applications like Path is image loading. The traditional method of loading individual images from disk is just too slow, especially while scrolling. Fast Image Cache was created specifically to solve this problem.\n"

  s.license      = { :type => 'MIT', :text => <<-LICENSE
                      The MIT License (MIT)
                      Copyright (c) 2014
                      Permission is hereby granted, free of charge, to any person obtaining a copy
                      of this software and associated documentation files (the "Software"), to deal
                      in the Software without restriction, including without limitation the rights
                      to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
                      copies of the Software, and to permit persons to whom the Software is
                      furnished to do so, subject to the following conditions:
                      The above copyright notice and this permission notice shall be included in
                      all copies or substantial portions of the Software.
                      THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
                      IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
                      FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
                      AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
                      LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
                      OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
                      THE SOFTWARE.
                      LICENSE
                  }
  
  s.requires_arc = true

  s.source       = { :git => "https://github.com/path/FastImageCache.git", :tag => "1.3" }
  s.source_files = "FastImageCache"

end
