$pdflatex = 'pdflatex --shell-escape -synctex=1 %O %S';
add_cus_dep('mat', 'mah', 0, 'makeglo2gls');
add_cus_dep('glo', 'gls', 0, 'makeglo2gls');
add_cus_dep('acn', 'acr', 0, 'makeglo2gls');
sub makeglo2gls {
        system("makeglossaries $_[0]");
}


push @generated_exts, 'glo', 'gls', 'glg';
push @generated_exts, 'acn', 'acr', 'alg';
push @generated_exts, 'mat', 'mah', 'mag';
push @generated_exts, 'bbl', 'mah', 'mag';
$clean_ext .= ' %R.ist %R.xdy %R.bbl %R.synctex.gz';
