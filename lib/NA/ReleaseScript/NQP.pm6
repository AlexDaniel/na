use NA::ReleaseScript;
use NA::ReleaseConstants;

unit class NA::ReleaseScript::NQP does NA::ReleaseScript;

method prefix { 'nqp-' }
method steps {
    return  clone       => step1-clone,
            bump-vers   => step2-bump-versions,
            build       => step3-build,
            tar         => step4-tar,
            tar-build   => step5-tar-build,
            tag         => step6-tag,
            tar-sign    => step7-tar-sign,
            tar-copy    => step8-tar-copy,
}

sub step1-clone {
    return qq:to/SHELL_SCRIPT_END/;
    git clone $nqp-repo nqp                                         &&
    cd nqp                                                          ||
    \{ echo '$na-fail NQP: Clone repo'; exit 1; \}
    SHELL_SCRIPT_END
}

sub step2-bump-versions {
    return %*ENV<NA_DEBUG>
    ?? qq:to/SHELL_SCRIPT_END/
        echo '$moar-ver' > tools/build/MOAR_REVISION
        git commit -m 'bump MoarVM version to $moar-ver' \\
            tools/build/MOAR_REVISION
        echo '$nqp-ver' > VERSION
        git commit -m 'bump VERSION to $nqp-ver' VERSION
        $with-github-credentials git push
        SHELL_SCRIPT_END
    !! qq:to/SHELL_SCRIPT_END/;
        echo '$moar-ver' > tools/build/MOAR_REVISION                    &&
        git commit -m 'bump MoarVM version to $moar-ver' \\
            tools/build/MOAR_REVISION                                   ||
        \{ echo '$na-fail NQP: Bump MoarVM version'; exit 1; \}

        echo '$nqp-ver' > VERSION                                       &&
        git commit -m 'bump VERSION to $nqp-ver' VERSION
        $with-github-credentials git push                               ||
        \{ echo '$na-fail NQP: Bump nqp version'; exit 1; \}
        SHELL_SCRIPT_END
}

sub step3-build {
    return qq:to/SHELL_SCRIPT_END/;
    perl Configure.pl --gen-moar \\
            --backend=moar{',jvm' unless %*ENV<NA_NO_JVM> }         &&
        make                                                        &&
        make m-test                                                 &&
        {'make j-test &&' unless %*ENV<NA_NO_JVM> }
        echo "$na-msg nqp tests OK"                                 ||
        \{ echo '$na-fail NQP: build and test'; exit 1; \}
    SHELL_SCRIPT_END
}

sub step4-tar {
    return qq:to/SHELL_SCRIPT_END/;
    make release VERSION=$nqp-ver                                   &&
    cp nqp-$nqp-ver.tar.gz $dir-temp                                &&
    cd $dir-temp                                                    &&
    tar -xvvf nqp-$nqp-ver.tar.gz                                    &&
    cd nqp-$nqp-ver                                                 ||
    \{
        echo '$na-fail NQP: Make release tarball and copy testing area';
        exit 1;
    \}
    SHELL_SCRIPT_END
}

sub step5-tar-build {
    return qq:to/SHELL_SCRIPT_END/;
    perl Configure.pl --gen-moar \\
        --backend=moar{',jvm' unless %*ENV<NA_NO_JVM> }             &&
    make                                                            &&
    make m-test                                                     &&
    {'make j-test &&' unless %*ENV<NA_NO_JVM> }
    echo "$na-msg nqp release tarball tests OK"                     ||
    \{ echo '$na-fail NQP: Build and test the release tarball'; exit 1; \}
    SHELL_SCRIPT_END
}

sub step6-tag {
    return qq:to/SHELL_SCRIPT_END/;
    cd $dir-nqp                                                     &&
    $with-gpg-passphrase git tag -u $tag-email \\
        -s -a -m 'tag release $nqp-ver' $nqp-ver                    &&
    $with-github-credentials git push --tags                        ||
    \{ echo '$na-fail NQP: Tag nqp'; exit 1; \}
    SHELL_SCRIPT_END
}

sub step7-tar-sign {
    return qq:to/SHELL_SCRIPT_END/;
    gpg --batch --no-tty --passphrase-fd 0 -b \\
        --armor nqp-$nqp-ver.tar.gz                                 ||
    \{ echo '$na-fail NQP: Sign the tarball'; exit 1; \}
    $gpg-keyphrase
    SHELL_SCRIPT_END
}

sub step8-tar-copy {
    return qq:to/SHELL_SCRIPT_END/;
    cp nqp-$nqp-ver.tar.gz* $dir-tarballs                           &&
    cd $release-dir                                                 &&
    echo '$na-msg nqp release DONE'                                 ||
    \{ echo '$na-fail NQP: copy tarball to release dir'; exit 1; \}
    SHELL_SCRIPT_END
}
