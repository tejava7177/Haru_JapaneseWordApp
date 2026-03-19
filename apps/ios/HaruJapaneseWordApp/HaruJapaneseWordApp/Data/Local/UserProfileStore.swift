import Foundation

struct UserProfileStore {
    private let userDefaults: UserDefaults

    private let nicknameKey = "profile_nickname"
    private let bioKey = "profile_bio"
    private let instagramKey = "profile_instagram"
    private let profileImageUrlKey = "profile_image_url"
    private let avatarDataKey = "profile_avatar_data"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func load() -> UserProfile {
        let nickname = userDefaults.string(forKey: nicknameKey) ?? "하루"
        let bio = userDefaults.string(forKey: bioKey) ?? ""
        let instagram = userDefaults.string(forKey: instagramKey) ?? ""
        let avatar = userDefaults.data(forKey: avatarDataKey)
        return UserProfile(
            nickname: nickname,
            bio: bio,
            instagramId: instagram,
            profileImageUrl: userDefaults.string(forKey: profileImageUrlKey),
            avatarData: avatar
        )
    }

    func save(profile: UserProfile) {
        userDefaults.set(profile.nickname, forKey: nicknameKey)
        userDefaults.set(profile.bio, forKey: bioKey)
        userDefaults.set(profile.instagramId, forKey: instagramKey)
        userDefaults.set(profile.profileImageUrl, forKey: profileImageUrlKey)
        userDefaults.set(profile.avatarData, forKey: avatarDataKey)
    }

    func updateNickname(_ nickname: String) {
        userDefaults.set(nickname, forKey: nicknameKey)
    }

    func updateBio(_ bio: String) {
        userDefaults.set(bio, forKey: bioKey)
    }

    func updateInstagram(_ instagramId: String) {
        userDefaults.set(instagramId, forKey: instagramKey)
    }

    func updateAvatar(_ data: Data?) {
        userDefaults.set(data, forKey: avatarDataKey)
    }

    func updateProfileImageUrl(_ url: String?) {
        userDefaults.set(url, forKey: profileImageUrlKey)
    }
}
