curl -LJ https://api.github.com/repos/LoganKoller/lshslcp/tarball/main -o lshslcp.tar.gz
tempdir=$(mktemp -d)
sudo tar -xzf lshslcp.tar.gz -C "$tempdir"
ofn=$(find "$tempdir" -mindepth 1 -maxdepth 1 -type d)
sudo mv "$ofn" "$tempdir/lshslcp"
sudo mv "$tempdir/lshslcp" "./"
sudo rm -rf "$tempdir"
sudo apt-get install dos2unix
sudo dos2unix lshslcp/main.sh
