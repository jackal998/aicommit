module Common
  class OsClient
    # OS-specific commands
    CLIPBOARD_COMMANDS = {
      darwin: "pbcopy",
      linux: "xclip -selection clipboard",
      mswin: "clip",
      mingw: "clip"
    }.freeze

    attr_reader :host_os

    def initialize
      @host_os = RbConfig::CONFIG["host_os"]
    end

    def copy_to_clipboard(content)
      command = CLIPBOARD_COMMANDS[host_os.to_sym]
      if command
        IO.popen(command, "w") { |f| f << content }
      else
        puts "Warning: Clipboard functionality not supported on your OS".yellow
      end
    end
  end
end 
