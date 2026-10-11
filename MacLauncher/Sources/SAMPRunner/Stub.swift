#if !os(macOS)
@main
enum UnsupportedPlatform {
    static func main() {
        print("The SA-MP Runner app is macOS-only. Use `samp-runner` for the command line.")
    }
}
#endif
