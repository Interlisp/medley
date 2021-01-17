BEGIN {hash="0"; gc = 0;}
function processgroup(group, gc) {
    printf("# processing group of %d files -- ",gc);
    for (i=1; i <= gc; i++) printf("'%s' ",group[i]);
    printf("\n");
    printf("rm '%s' && ln '%s' '%s'\n", group[gc],group[1], group[gc]);
}
hash == $1 && 1 == index($2, group[1]) {gc = gc + 1; group[gc] = $2; }
hash != $1 || 1 != index($2, group[1]) { if (gc > 1) processgroup(group, gc); delete group; hash = $1; gc = 1; group[gc] = $2;}
