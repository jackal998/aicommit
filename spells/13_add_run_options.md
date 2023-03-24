Prompt:
我的ＧＥＭ現在有一個執行檔：
#!/usr/bin/env ruby

require_relative "../lib/aicommit"

Aicommit.new.run

我想要在執行的時候輸入一個參數`-v`例如：`aicommit -v`，其功能是回傳當前使用的這一個ＧＥＭ的版本，應該要怎麼做？

ChatGPT:
你可以使用OptionParser來解析命令行參數。以下是修改後的程式碼：

```
#!/usr/bin/env ruby

require 'optparse'
require_relative "../lib/aicommit"

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: aicommit [options]"

  opts.on("-v", "--version", "Show version") do |v|
    options[:version] = v
  end
end.parse!

if options[:version]
  puts "aicommit version #{Aicommit::VERSION}"
else
  Aicommit.new.run
end
```

在這個程式碼中，我們使用OptionParser來解析命令行參數。當使用者輸入`-v`或`--version`時，我們會顯示當前使用的aicommit版本。如果沒有輸入任何命令行參數，我們會執行Aicommit類的run方法。注意，我們需要在Aicommit類中定義一個版本號常量，例如：

```
class Aicommit
  VERSION = "1.0.0"
  
  def run
    # ...
  end
end
```

這樣，當使用者輸入`aicommit -v`時，就會顯示當前使用的版本號了。

Prompt:
我想要新增功能：
1，輸入參數`-c`例如：`aicommit -c`時，觸發TokenManager.write!這個方法
2，若輸入定義以外的任何參數時結束程序並列出所有合法參數給使用者
3，若沒有輸入任何參數時則正常執行Aicommit.new.run
請問我該怎麼做？

ChatGPT:
你可以使用OptionParser來解析命令行參數。以下是修改後的程式碼：

```
#!/usr/bin/env ruby

require 'optparse'
require_relative "../lib/aicommit"
require_relative "../lib/token_manager"

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: aicommit [options]"

  opts.on("-v", "--version", "Show version") do |v|
    options[:version] = v
  end

  opts.on("-c", "--create_token", "Create a new OpenAI API token") do |c|
    options[:create_token] = c
  end
end.parse!

if options[:version]
  puts "aicommit version #{Aicommit::VERSION}"
elsif options[:create_token]
  TokenManager.write!
elsif ARGV.any?
  puts "Invalid option. Usage: aicommit [options]"
  puts ""
  puts "Options:"
  puts "  -c, --create_token\tCreate a new OpenAI API token"
  puts "  -v, --version\t\tShow version"
else
  Aicommit.new.run
end
```

在這個程式碼中，我們使用OptionParser來解析命令行參數。當使用者輸入`-v`或`--version`時，我們會顯示當前使用的aicommit版本。當使用者輸入`-c`或`--create_token`時，我們會執行TokenManager.write!方法。如果使用者輸入了定義以外的任何參數，我們會顯示所有合法參數。如果使用者沒有輸入任何參數，我們會執行Aicommit類的run方法。

請注意，如果你的TokenManager.write!方法需要使用者輸入一些敏感信息，例如帳號密碼，你需要在方法中對這些敏感信息進行適當的處理，以保護使用者的隱私。
