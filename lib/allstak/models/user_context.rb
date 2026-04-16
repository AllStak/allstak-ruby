module AllStak
  module Models
    class UserContext
      attr_accessor :id, :email, :ip

      def initialize(id: nil, email: nil, ip: nil)
        @id = id
        @email = email
        @ip = ip
      end

      def to_h
        out = {}
        out[:id]    = @id    unless @id.nil?
        out[:email] = @email unless @email.nil?
        out[:ip]    = @ip    unless @ip.nil?
        out
      end
    end

    class RequestContext
      attr_accessor :method, :path, :host, :status_code, :user_agent

      def initialize(method: nil, path: nil, host: nil, status_code: nil, user_agent: nil)
        @method = method
        @path = path
        @host = host
        @status_code = status_code
        @user_agent = user_agent
      end

      def to_h
        out = {}
        out[:method]     = @method      unless @method.nil?
        out[:path]       = @path        unless @path.nil?
        out[:host]       = @host        unless @host.nil?
        out[:statusCode] = @status_code unless @status_code.nil?
        out[:userAgent]  = @user_agent  unless @user_agent.nil?
        out
      end
    end
  end
end
