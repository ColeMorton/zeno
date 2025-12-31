import Link from 'next/link';

export function Footer() {
  return (
    <footer className="bg-black/90 border-t border-gray-800 py-12 px-6">
      <div className="max-w-7xl mx-auto">
        <div className="grid grid-cols-1 md:grid-cols-4 gap-8">
          <div>
            <div className="flex items-center gap-2 mb-4">
              <span className="text-2xl">⛰️</span>
              <span className="font-bold text-xl text-white">The Ascent</span>
            </div>
            <p className="text-gray-400 text-sm">
              Fortify your NFTs with Bitcoin. Built to last generations.
            </p>
          </div>

          <div>
            <h4 className="font-semibold text-white mb-4">Journey</h4>
            <ul className="space-y-2 text-gray-400 text-sm">
              <li>
                <Link href="/dashboard" className="hover:text-white transition-colors">
                  Dashboard
                </Link>
              </li>
              <li>
                <Link href="/achievements" className="hover:text-white transition-colors">
                  Achievements
                </Link>
              </li>
              <li>
                <Link href="/leaderboard" className="hover:text-white transition-colors">
                  Leaderboard
                </Link>
              </li>
            </ul>
          </div>

          <div>
            <h4 className="font-semibold text-white mb-4">Community</h4>
            <ul className="space-y-2 text-gray-400 text-sm">
              <li>
                <a
                  href="https://twitter.com/btcnft"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="hover:text-white transition-colors"
                >
                  Twitter
                </a>
              </li>
              <li>
                <a
                  href="https://discord.gg/btcnft"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="hover:text-white transition-colors"
                >
                  Discord
                </a>
              </li>
            </ul>
          </div>

          <div>
            <h4 className="font-semibold text-white mb-4">Protocol</h4>
            <ul className="space-y-2 text-gray-400 text-sm">
              <li>
                <a
                  href="https://docs.btcnft.io"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="hover:text-white transition-colors"
                >
                  Documentation
                </a>
              </li>
              <li>
                <a
                  href="https://github.com/btcnft"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="hover:text-white transition-colors"
                >
                  GitHub
                </a>
              </li>
            </ul>
          </div>
        </div>

        <div className="mt-12 pt-8 border-t border-gray-800 text-center text-gray-500 text-sm">
          <p>The mountain has always been here. It will always be here.</p>
        </div>
      </div>
    </footer>
  );
}
