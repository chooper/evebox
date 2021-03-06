def save_env!
  File.open(".env", "w") do |f|
    f.puts "EVE_KEY_ID=#{ENV['EVE_KEY_ID']}"
    f.puts "EVE_TOKEN=#{ENV['EVE_TOKEN']}"
    f.close
  end
end

# Monkey patch ENV
ENV.instance_eval do
  def source(filename)
    return {} unless File.exists?(filename)

    env = File.read(filename).split("\n").inject({}) do |hash, line|
      if line =~ /\A([A-Za-z_0-9]+)=(.*)\z/
        key, val = [$1, $2]
        case val
          when /\A'(.*)'\z/ then hash[key] = $1
          when /\A"(.*)"\z/ then hash[key] = $1.gsub(/\\(.)/, '\1')
          else hash[key] = val
        end
      end
      hash
    end

    env.each { |k,v| ENV[k] = v unless ENV[k] }
  end
end
