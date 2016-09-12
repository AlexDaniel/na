use NA::ReleaseScript;
use NA::ReleaseConstants;

unit class NA::ReleaseScript::Rakudo does NA::ReleaseScript;

method prefix { 'r-' }
method steps {
    return  clone      => step1-clone,
            prep-ann   => step2-prep-announcement,
            # bump-vers  => step3-bump-versions,
            build      => step4-build,
            p5         => step5-p5,
            stress     => step6-stress,
            stress-v6c => step7-stress-v6c,
            tar        => step8-tar,
            tar-build  => step9-tar-build,
            tar-p5     => step10-tar-p5,
            tar-stress => step11-tar-stress,
            tag        => step12-tag,
            tar-sign   => step13-tar-sign,
            tar-copy   => step14-tar-copy,
}

sub step1-clone {
    return qq:to/SHELL_SCRIPT_END/;
    rm -fr $dir-rakudo
    git clone $rakudo-repo $dir-rakudo                              ||
    \{ echo '$na-fail Rakudo: clone Rakudo'; exit 1; \}
    SHELL_SCRIPT_END
}

sub step2-prep-announcement {
    return qq:to/SHELL_SCRIPT_END/;
    if [ ! -e docs/announce/$rakudo-ver.md ] ; then
        rm -fr $dir-temp
        mkdir $dir-temp                                             &&
        cd $dir-temp                                                &&
        git clone $nqp-repo                                         &&
        git clone $doc-repo                                         &&
        git clone $moar-repo                                        &&
        git clone $roast-repo                                       &&
        cd $dir-rakudo                                              ||
        \{ echo '$na-fail Rakudo: generate release announcement'; exit 1; \}

        $perl6-source
        perl6 tools/create-release-announcement.pl              \\
                --doc=$dir-temp/doc                             \\
                --nqp=$dir-temp/nqp                             \\
                --moar=$dir-temp/MoarVM                         \\
                --roast=$dir-temp/roast                         \\
            > docs/announce/$rakudo-ver.md                          &&
        git add docs/announce/$rakudo-ver.md                        &&
        git commit -m                                           \\
            'Generate release announcement for $rakudo-ver'         ||
        \{ echo '$na-fail Rakudo: generate release announcement'; exit 1; \}
    fi
    SHELL_SCRIPT_END
}

sub step3-bump-versions {
    return qq:to/SHELL_SCRIPT_END/;
    cd $dir-rakudo                                                  &&
    echo $nqp-ver > tools/build/NQP_REVISION                        &&
    git commit -m '[release] bump NQP revision'                 \\
        tools/build/NQP_REVISION                                    &&

    echo $rakudo-ver > VERSION                                      &&
    git commit -m '[release] bump VERSION to $rakudo-ver' VERSION   &&
    git pull --rebase                                               &&
    $with-github-credentials git push                               ||
    \{ echo '$na-fail Rakudo: bump NQP and Rakudo versions'; exit 1; \}
    SHELL_SCRIPT_END
}

sub step4-build {
    return qq:to/SHELL_SCRIPT_END/;
    perl Configure.pl --gen-moar --backends=$rakudo-backends        &&
    make                                                            &&
    make install                                                    &&
    make test                                                       ||
    \{ echo '$na-fail Rakudo: build and make test'; exit 1; \}
    SHELL_SCRIPT_END
}

sub step5-p5 {
    return qq:to/SHELL_SCRIPT_END/;
    $perl5-source
    git clone https://github.com/tadzik/panda                       &&
    export PATH=`pwd`/install/bin:\$PATH                            &&
    cd panda                                                        &&
    perl6 bootstrap.pl                                              &&
    cd ..                                                           &&
    export PATH=`pwd`/install/share/perl6/site/bin:\$PATH           &&
    panda install Inline::Perl5                                     &&
    ./perl6 -MInline::Perl5 -e ''                                   ||
    \{ echo '$na-fail Rakudo: install Inline::Perl5'; exit 1; \}
    SHELL_SCRIPT_END
}

sub step6-stress {
    return qq:to/SHELL_SCRIPT_END/;
    TEST_JOBS=$cores make stresstest                                &&
    echo "$na-msg Rakudo stresstest (master) OK"                    ||
    \{ echo '$na-fail Rakudo: make stresstest (master)'; exit 1; \}
    SHELL_SCRIPT_END
}

sub step7-stress-v6c {
    return qq:to/SHELL_SCRIPT_END/;
    cd t/spec                                                       &&
    git checkout 6.c-errata                                         &&
    cd ../..                                                        &&
    TEST_JOBS=$cores make stresstest                                &&
    echo "$na-msg Rakudo stresstest (6.c-errata) OK"                ||
    \{ echo '$na-fail Rakudo: make stresstest (6.c-errata)'; exit 1; \}
    SHELL_SCRIPT_END
}

sub step8-tar {
    return qq:to/SHELL_SCRIPT_END/;
    make release VERSION=$rakudo-ver                                &&
    cp rakudo-$rakudo-ver.tar.gz $dir-temp                          &&
    cd $dir-temp                                                    &&
    tar -xvvf rakudo-$rakudo-ver.tar.gz                             &&
    cd rakudo-$rakudo-ver                                           ||
    \{
        echo '$na-fail Rakudo: make release tarball and copy to test area';
        exit 1;
    \}
    SHELL_SCRIPT_END
}

sub step9-tar-build {
    return qq:to/SHELL_SCRIPT_END/;
    perl Configure.pl --gen-moar --backends=$rakudo-backends        &&
    make                                                            &&
    make install                                                    &&
    make test                                                       ||
    \{ echo '$na-fail Rakudo: (release tarball) build and make test'; exit 1; \}
    SHELL_SCRIPT_END
}

sub step10-tar-p5 {
    return qq:to/SHELL_SCRIPT_END/;
    $perl5-source
    git clone https://github.com/tadzik/panda                       &&
    export PATH=`pwd`/install/bin:\$PATH                            &&
    cd panda                                                        &&
    perl6 bootstrap.pl                                              &&
    cd ..                                                           &&
    export PATH=`pwd`/install/share/perl6/site/bin:\$PATH           &&
    panda install Inline::Perl5                                     &&
    ./perl6 -MInline::Perl5 -e ''                                   ||
    \{
        echo '$na-fail Rakudo: (tarball testing) install Inline::Perl5';
        exit 1;
    \}
    SHELL_SCRIPT_END
}

sub step11-tar-stress {
    return qq:to/SHELL_SCRIPT_END/;
    TEST_JOBS=$cores make stresstest                                ||
    \{ echo '$na-fail Rakudo: make stresstest (tarball testing)'; exit 1; \}
    SHELL_SCRIPT_END
}

sub step12-tag {
    return qq:to/SHELL_SCRIPT_END/;
    cd $dir-rakudo                                                  &&
    $with-gpg-passphrase git tag -u $tag-email                  \\
        -s -a -m "tag release #$rakudo-rver" $rakudo-ver            &&
    $with-github-credentials git push --tags                        ||
    \{ echo '$na-fail Rakudo: make stresstest (tarball testing)'; exit 1; \}
    SHELL_SCRIPT_END
}

sub step13-tar-sign {
    return qq:to/SHELL_SCRIPT_END/;
    cd $dir-rakudo                                                  &&
    gpg --batch --no-tty --passphrase-fd 0 -b \\
        --armor rakudo-$rakudo-ver.tar.gz                           ||
    \{ echo '$na-fail Rakudo: Sign the tarball'; exit 1; \}
    $gpg-keyphrase
    SHELL_SCRIPT_END
}

sub step14-tar-copy {
    return qq:to/SHELL_SCRIPT_END/;
    cd $dir-rakudo                                                  &&
    cp rakudo-$rakudo-ver.tar.gz* $dir-tarballs                     &&
    cd $release-dir                                                 &&
    echo '$na-msg Rakudo release DONE'                              ||
    \{ echo '$na-fail Rakudo: copy tarball to release dir'; exit 1; \}
    SHELL_SCRIPT_END
}
