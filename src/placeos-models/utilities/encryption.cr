require "base64"
require "crypto/subtle"
require "openssl"
require "uuid"

# Provides symmetric key encryption/decryption
module PlaceOS::Encryption
  Log = ::Log.for(self)

  # Privilege levels
  enum Level
    None
    Support
    Admin
    NeverDisplay

    def visible_for?(user : Model::User | Model::UserJWT)
      if user.is_admin?
        self <= Admin
      elsif user.is_support?
        self <= Support
      else
        self <= None
      end
    end
  end

  private SECRET = ENV["PLACE_SERVER_SECRET"]?.tap { |k| Log.warn { "using insecure default PLACE_SERVER_SECRET" } if k.nil? } || "super secret, do not leak"
  private CIPHER = "aes-256-gcm"

  # Encrypt a test string with the encryption context in the cipher context
  # and test for equality
  #
  def self.check?(encrypted : String, test : String, id : String, level : Level) : Bool
    return true if level == Level::None && encrypted == test
    return false unless is_encrypted?(encrypted)

    salt, iv, cipher_text = extract_context(encrypted)

    _, key = generate_key(id: id, level: level, salt: salt)

    encrypted_test = encrypt_data(data: test, key: key, salt: salt, iv: ::Base64.decode(iv))
    Crypto::Subtle.constant_time_compare(encrypted_test[:cipher_text], cipher_text)
  end

  # Encrypt clear text
  #
  # Does not encrypt
  # - previously encrypted
  # - values with `Level::NoEncryption` encryption
  def self.encrypt(string : String, id : String, level : Level) : String
    return string if level == Level::None || is_encrypted?(string)

    # Create unique key, salt
    salt, key = generate_key(id: id, level: level)

    encrypted_data = encrypt_data(data: string, key: key, salt: salt)

    # Generate storable value
    "\e#{salt}|#{encrypted_data[:iv]}|#{encrypted_data[:cipher_text]}"
  end

  # Decrypt cipher text.
  # Does not decrypt
  # - previously decrypted
  # - values with `Level::None` encryption
  #
  def self.decrypt(string : String, id : String, level : Level) : String
    return string if level == Level::None || !is_encrypted?(string)

    salt, iv, cipher_text = extract_context(string)

    _, key = generate_key(id: id, level: level, salt: salt)

    cipher = OpenSSL::Cipher.new(CIPHER)
    cipher.decrypt
    cipher.key = key
    cipher.iv = Base64.decode(iv)

    clear_data = IO::Memory.new
    clear_data.write(cipher.update(::Base64.decode(cipher_text)))

    String.new(clear_data.to_slice)
  end

  def self.decrypt_for(user : Model::User | Model::UserJWT, string : String, id : String, level : Level)
    if level.visible_for?(user)
      decrypt(string, id, level)
    else
      string
    end
  end

  # Check if string has been encrypted
  #
  def self.is_encrypted?(string : String)
    string[0]? == '\e'
  end

  # Create a key from user privilege, id and existing/random salt
  #
  protected def self.generate_key(level : Level, id : String, salt : String = UUID.random.to_s)
    digest = OpenSSL::Digest.new("SHA256")
    digest << salt
    digest << SECRET
    digest << id
    digest << level.to_s
    {salt, digest.final}
  end

  # Encrypt data and Base64 the resulting slice
  #
  protected def self.encrypt_data(data : String, key : Bytes, salt : String, iv : Bytes? = nil) : NamedTuple(cipher_text: String, iv: String)
    # Initialise cipher
    cipher = OpenSSL::Cipher.new(CIPHER)

    cipher.encrypt
    cipher.key = key

    cipher.iv = (iv ||= cipher.random_iv)

    # Encrypt clear text
    encrypted_data = IO::Memory.new
    encrypted_data.write(cipher.update(data))
    encrypted_data.write(cipher.final)

    {
      cipher_text: ::Base64.strict_encode(encrypted_data.to_slice),
      iv:          ::Base64.strict_encode(iv),
    }
  end

  # Pick off salt, initialisation vector and cipher text embedded in encrypted string
  protected def self.extract_context(encrypted : String)
    salt, iv, cipher_text = encrypted[1..-1].split('|')

    ({salt, iv, cipher_text})
  end
end
