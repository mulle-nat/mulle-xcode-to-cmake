#! /bin/sh
#
# Generate a formula formulle-xcode-settings stand alone
#
PROJECT=MulleXcodeSettings
TARGET=mulle-xcode-settings
HOMEPAGE="http://www.mulle-kybernetik.com/software/git/${TARGET}"
DESC="Edit Xcode build settings from the command line"
AGVTAG="`agvtool what-version -terse 2> /dev/null`"

VERSION="${1:-$AGVTAG}"
shift
ARCHIVEURL="${1:-http://www.mulle-kybernetik.com/software/git/${TARGET}/tarball/$VERSION}"
shift


fail()
{
   echo "$@" >&2
   exit 1
}

[ ! -z "$VERSION"  ]   || fail "no version"
[ ! -z "$ARCHIVEURL" ] || fail "no archive url"


check_for_git_tag()
{
   git rev-parse "${VERSION}" >/dev/null 2>&1 || fail "No tag ${VERSION} found"
}


check_for_pristine_git_repo()
{
      local files
   # allow project.pbxproj to be dirty.. because it's just too painful
   # otherwise
   files=`expr $(git status --porcelain 2>/dev/null| egrep "^(M| M|\?)" | egrep -v '.xcodeproj/project.pbxproj' | wc -l)`

   [ $files -eq 0 ] || fail "GIT repository not in pristine state"
}


download_and_chksum_archive()
{
   TMPARCHIVE="/tmp/${PROJECT}-${VERSION}-archive"

   if [ ! -f  "${TMPARCHIVE}" ]
   then
      curl -L -o "${TMPARCHIVE}" "${ARCHIVEURL}"
      if [ $? -ne 0 -o ! -f "${TMPARCHIVE}" ]
      then
         fail "Download failed"
      fi
   else
      echo "using cached file \"${TMPARCHIVE}\" instead of downloading again" >&2
   fi

   #
   # anything less than 17 KB is wrong
   #
   size="`du -k "${TMPARCHIVE}" | awk '{ print $ 1}'`"
   if [ $size -lt 17 ]
   then
      echo "Archive truncated or missing" >&2
      cat "${TMPARCHIVE}" >&2
      rm "${TMPARCHIVE}"
      exit 1
   fi

   HASH="`shasum -p -a 256 "${TMPARCHIVE}" | awk '{ print $1 }'`"
}


produce_rb_file()
{
   cat <<EOF
class ${PROJECT} < Formula
  homepage "${HOMEPAGE}"
  desc "${DESC}"
  url "${ARCHIVEURL}"
  version "${VERSION}"
  sha256 "${HASH}"

  depends_on :xcode => :build
  depends_on :macos => :snow_leopard

#  depends_on "zlib"
  def install
     xcodebuild "install", "-target", "${TARGET}", "DSTROOT=/", "INSTALL_PATH=#{bin}"
  end

  test do
    system "#{bin}/${TARGET}", "-version"
  end
end
# FORMULA ${TARGET}.rb
EOF
}


main()
{
   check_for_git_tag
   check_for_pristine_git_repo
   download_and_chksum_archive
   produce_rb_file
}

main
