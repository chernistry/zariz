import Kingfisher
import SwiftUI

public struct RemoteAvatarView: View {
    let identifier: String
    var size: CGFloat = 56

    public init(identifier: String, size: CGFloat = 56) {
        self.identifier = identifier
        self.size = size
    }

    private var imageURL: URL? {
        guard let encoded = identifier.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) else {
            return URL(string: "https://source.boringavatars.com/beam/\(Int(size * 2))/zariz")
        }
        return URL(string: "https://source.boringavatars.com/beam/\(Int(size * 2))/\(encoded)?colors=264653,2a9d8f,e9c46a,f4a261,e76f51")
    }

    public var body: some View {
        KFImage(imageURL)
            .placeholder { shimmerPlaceholder }
            .retry(maxCount: 2, interval: .seconds(2))
            .onFailureImage(UIImage(systemName: "shippingbox.fill"))
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.medium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.medium, style: .continuous)
                    .stroke(DS.Color.brandPrimary.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: DS.Color.brandPrimary.opacity(0.08), radius: 8, x: 0, y: 4)
    }

    private var shimmerPlaceholder: some View {
        RoundedRectangle(cornerRadius: DS.Radius.medium)
            .fill(DS.Color.surfaceElevated)
            .frame(width: size, height: size)
            .shimmer()
    }
}
