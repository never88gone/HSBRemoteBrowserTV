#!/usr/bin/env ruby
# 本地 App Store 截图与媒体资源合规性检测脚本 (参考 THLDance 规范)
require 'open3'

root = File.expand_path(__dir__)
errors = []
counts = Hash.new(0)

locales = %w[zh-Hans en-US]
locales.each do |locale|
  paths = Dir.glob(File.join(root, 'screenshots', locale, '*')).select do |path|
    File.file?(path) && %w[.png .jpg .jpeg].include?(File.extname(path).downcase)
  end
  
  if paths.empty?
    errors << "未找到语言 [#{locale}] 的截图文件"
    next
  end

  paths.each do |path|
    output, status = Open3.capture2e('sips', '-g', 'pixelWidth', '-g', 'pixelHeight', '-g', 'hasAlpha', path)
    unless status.success?
      errors << "无法通过 sips 读取文件: #{path}"
      next
    end

    width = output[/pixelWidth:\s+(\d+)/, 1].to_i
    height = output[/pixelHeight:\s+(\d+)/, 1].to_i
    alpha = output[/hasAlpha:\s+(\w+)/, 1]

    device = case [width, height]
             when [1320, 2868], [1290, 2796], [1260, 2736] then 'iPhone 6.9 inch'
             when [1284, 2778], [1242, 2688] then 'iPhone 6.5 inch'
             when [1206, 2622] then 'iPhone 6.3 inch'
             when [416, 496] then 'Apple Watch 46 mm (Series 10)'
             when [396, 484] then 'Apple Watch 45 mm (Series 7/8/9)'
             when [368, 448] then 'Apple Watch 44 mm (Series 4/5/6/SE)'
             when [312, 390] then 'Apple Watch 42 mm (Series 3)'
             end

    errors << "不合规的截图尺寸 #{width}x#{height}: #{path}" unless device
    errors << "包含被 App Store 禁止的 Alpha 透明通道: #{path}" unless alpha == 'no'
    counts["#{locale} - #{device}"] += 1 if device
    puts "[#{locale}] #{File.basename(path)}: #{width}x#{height}, alpha=#{alpha} (#{device})"
  end
end

unless errors.empty?
  warn "\n❌ 发现以下不合规项:"
  warn errors.uniq.join("\n")
  exit 1
end

puts "\n✅ 检验通过: 共 #{counts.values.sum} 张官方标准截图，尺寸与色彩通道完全符合 App Store 准入规范！"
