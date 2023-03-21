Prompt:
我想要修改一下功能，先更新一下目前的code是這個樣子：
require "git"

if !Dir.exist?(".git")
  raise "Not a git repository!"
end

commit_message = ""

git = Git.open(".")

diffs = git.diff.each do |diff|
  patch = diff.patch
  first_line = patch.lines.first
  last_line = patch.lines.last

  commit_message = "#{first_line} #{last_line}"
end

loop do
  puts "commit_message: #{commit_message}"
  puts "Do you want to keep this commit_message? (Y/N) (or Q to quit)"
  command = gets.chomp
  if command =~ /^[Yy]$/
    git.commit_all(commit_message)
    puts "Committed all changes with message: #{commit_message}"
    break
  elsif command =~ /^[Nn]$/
    puts "Please enter your new commit_message:"
    commit_message = gets.chomp
  elsif command =~ /^[Qq]$/
    puts "Quit without committing."
    exit
  else
    puts "Invalid command. Please enter Y, N, or Q."
  end
end

要修改的地方是將git.diff裡面patch的內容組合成一個字串，並且送到ChatGPT，然後得到適用於這一次git diff的commit message，應該要怎麼修改？

ChatGPT:
如果你想要透過與ChatGPT對話得到適用於這次git diff的commit message，你需要先安裝OpenAI API的ruby gem，然後使用你的API key進行認證，接著就可以使用OpenAI API了。這是一個使用OpenAI API的範例：

```ruby
require "openai"

OpenAI.api_key = "YOUR_API_KEY_HERE"

def generate_commit_message(diff)
  prompt = "Please generate a commit message based on the following diff:\n#{diff}"
  completions = OpenAI::Completion.create(
    engine: "davinci-codex",
    prompt: prompt,
    max_tokens: 64,
    n: 1,
    stop: ["\n"],
    temperature: 0.7
  )
  completions.choices.first.text.strip
end
```
這個範例使用OpenAI的davinci-codex模型生成一個適用於這次git diff的commit message。在generate_commit_message函數中，我們將diff作為prompt傳入OpenAI的API，並使用max_tokens指定最大輸出字數，使用temperature控制生成commit message的創意程度。最後，這個函數返回生成的commit message。

接下來，你需要將原本組合commit message的那一段程式碼改為使用這個新的函數：

```ruby
commit_message = generate_commit_message(diff)
```
這樣就可以讓ChatGPT生成適用於這次git diff的commit message了。

Prompt:
據我所知，git.diff可能是很多個檔案組成的陣列，請問要怎麼組合成適合ChatGPT的字串？

ChatGPT:
對的，git.diff 返回一個包含所有差異的陣列，而每個差異可能涉及多個檔案。你可以考慮把差異串成一個長字串，再傳給ChatGPT 進行語言生成。

以下是一種實現方法：

```ruby
diffs = git.diff
patch_str = ""
diffs.each do |diff|
  patch = diff.patch
  patch_str += "\n\n#{diff.path}\n"
  patch_str += patch
end

# Call ChatGPT to generate commit message
commit_message = generate_commit_message(patch_str)
```
在這個例子中，我們將每個差異串成一個長字串 patch_str，其中包含了差異的檔案名稱和差異內容。接著，我們把 patch_str 傳遞給 generate_commit_message 方法，這個方法會使用 ChatGPT 進行語言生成，並返回一個適用於這一次差異的 commit message。

當然，你需要實現 generate_commit_message 方法，這個方法可以使用 OpenAI 的 API 進行語言生成，或者使用其他方式實現。
