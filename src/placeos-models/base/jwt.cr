require "jwt"
require "time"

module PlaceOS::Model
  # Base ORM for JWT
  abstract struct JWTBase
    include JSON::Serializable

    Log = ::Log.for(PlaceOS::Model).for("jwt")

    private ENC_PUBLIC_KEY  = ENV["JWT_PUBLIC"]?
    private ENC_PRIVATE_KEY = ENV["JWT_SECRET"]?.tap { |k| Log.warn { "insecure default JWT_SECRET" } unless k.presence || ENC_PUBLIC_KEY.presence }

    protected class_getter public_key do
      encoded_key = ENC_PUBLIC_KEY
      if encoded_key && encoded_key.presence
        String.new(Base64.decode(encoded_key))
      elsif ENC_PRIVATE_KEY.try &.presence
        key = OpenSSL::PKey::RSA.new(private_key)
        key.public_key.to_pem
      else
        Log.warn { "used default JWT public key" }
        <<-KEY
        -----BEGIN PUBLIC KEY-----
        MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAt01C9NBQrA6Y7wyIZtsy
        ur191SwSL3MjR58RIjZ5SEbSyzMG3r9v12qka4UtpB2FmON2vwn0fl/7i3Jgh1Xt
        h/s+TqgYXMebdd123wodrbex5pi3Q7PbQFT6hhNpnsjBh9SubTf+IeTIFeXUyqtq
        cDBmEoT5GxU6O+Wuch2GtbfEAmaDroy+uyB7P5DxpKLEx8nlVYgpx5g2mx2LufHv
        ykVnx4bFzLezU93SIEW6yjPwUmv9R+wDM/AOg60dIf3hCh1DO+h22aKT8D8ysuFo
        dpLTKCToI/AbK4IYOOgyGHZ7xizXHYXZdsqX5/zBFXu/NOVrSd/QBYYuCxbqe6tz
        4wIDAQAB
        -----END PUBLIC KEY-----
        KEY
      end
    end

    protected class_getter private_key do
      encoded_key = ENC_PRIVATE_KEY
      if encoded_key && encoded_key.presence
        String.new(Base64.decode(encoded_key))
      else
        Log.warn { "used default JWT private key" }
        <<-KEY
        -----BEGIN RSA PRIVATE KEY-----
        MIIEpAIBAAKCAQEAt01C9NBQrA6Y7wyIZtsyur191SwSL3MjR58RIjZ5SEbSyzMG
        3r9v12qka4UtpB2FmON2vwn0fl/7i3Jgh1Xth/s+TqgYXMebdd123wodrbex5pi3
        Q7PbQFT6hhNpnsjBh9SubTf+IeTIFeXUyqtqcDBmEoT5GxU6O+Wuch2GtbfEAmaD
        roy+uyB7P5DxpKLEx8nlVYgpx5g2mx2LufHvykVnx4bFzLezU93SIEW6yjPwUmv9
        R+wDM/AOg60dIf3hCh1DO+h22aKT8D8ysuFodpLTKCToI/AbK4IYOOgyGHZ7xizX
        HYXZdsqX5/zBFXu/NOVrSd/QBYYuCxbqe6tz4wIDAQABAoIBAQCEIRxXrmXIcMlK
        36TfR7h8paUz6Y2+SGew8/d8yvmH4Q2HzeNw41vyUvvsSVbKC0HHIIfzU3C7O+Lt
        9OeiBo2vTKrwNflBv9zPDHHoerlEBLsnNwQ7uEUeTWM9DHdBLwNaLzQApLD6q5iT
        OFW4NfIGpsydIt8R565PiNPDjIcTKwhbVdlsSbI87cLkQ9UuYIMRkvXSD1Q2cg3I
        VsC0SpE4zmfTe7YTZQ5yTxtsoLKPBXrSxhhGuhdayeN7A4YHFYVD39RuQ6/T2w2a
        W/0UaGOk8XWgydDpD5w9wiBdH2I4i6D35IynCcodc5JvmTajzJT+xj6aGjjvMSyq
        q5ZdwJ4JAoGBAOPdZgjbOCf3ONUoiZ5Qw/a4b4xJgMokgqZ5QGBF5GqV1Xsphmk1
        apYmgC7fmab/EOdycrQMS0am2FmtwX1f7gYgJoyWtK4TVkUc5rf+aoWi0ieIsegv
        rjhuiIAc12+vVIbegRgnq8mOI5icrwm6OkwdqHkwTt6VRYdJGEmu67n/AoGBAM3v
        RAd5uIjVwVDLXqaOpvF3pxWfl+cf6PJtAE5y+nbabeTmrw//fJMank3o7qCXkFZR
        F0OJ2tmENwV+LPM8Gy3So8YP2nkOz4bryaGrxQ4eMA+K9+RiACVaKv+tNx/NbyMS
        e9gg504u0cwa60XjM5KUKrmT3RXpY4YIfUPZ1J4dAoGAB6jalDOiSJ2j2G57acn3
        PGTowwN5g9IEXko3IsVWr0qIGZLExOaZxaBXsLutc5KhY9ZSCsFbCm3zWdhgZ7GA
        083i3dj3C970iHA3RToVJJbbj56ltFNd/OGiTwQpLcTsB3iVSFWVDbpsceXacG5F
        JWfd0O0RyaOk6a5IVbm+jMsCgYBglxAOfY4LSE8y6SCM+K3e5iNNZhymgHYPdwbE
        xPMrWgpfab/Evi2dBcgofM+oLU663bAOspMeoP/5qJPGxnNtC7ZbSMZNL6AxBVj+
        ZoW3uHsMXz8kNL8ixecTIxiO5xlwltPVrKExL46hsCKYFhfzcWGUx4DULTLMBCFU
        +M/cFQKBgQC+Ite962yJOnE+bjtSReOrvR9+I+YNGqt7vyRa2nGFxL7ZNIqHss5T
        VjaMgjzVJqqYozNT/74pE/b9UjYyMzO/EhrjUmcwriMMan/vTbYoBMYWvGoy536r
        4n455vizig2c4/sxU5yu9AF9Dv+qNsGCx2e9uUOTDUlHM9NXwxU9rQ==
        -----END RSA PRIVATE KEY-----
        KEY
      end
    end

    def self.decode(token : String, key : String? = nil, algorithm : JWT::Algorithm = JWT::Algorithm::RS256, validate : Bool = true)
      key = public_key || private_key if key.nil?
      decoded_payload, _ = JWT.decode(
        token: token,
        key: key,
        algorithm: algorithm,
        verify: true,
        validate: validate,
      )
      self.from_json(decoded_payload.to_json)
    end

    def encode(key : String? = nil, algorithm : JWT::Algorithm = JWT::Algorithm::RS256)
      key = self.class.private_key if key.nil?
      payload = JSON.parse(self.to_json)
      JWT.encode(
        payload: payload,
        key: key,
        algorithm: algorithm,
      )
    end
  end
end
