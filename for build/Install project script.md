
# Install Scripts

*python3 build-system/Make/Make.py \
    --overrideXcodeVersion --overrideBazelVersion \
    --bazel="$HOME/Sergey/MyProjects/Telegram-Fork/bazel-dist/bazel-arm" \
    --cacheDir="$HOME/Sergey/MyProjects/Telegram-Fork/telegram-bazel-cache" \
    generateProject \
    --configurationPath="$HOME/Sergey/MyProjects/Telegram-Fork/telegram-configuration" \
    --disableExtensions \
    --disableProvisioningProfiles*
