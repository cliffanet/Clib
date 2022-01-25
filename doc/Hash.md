# NAME

Clib::Hash - Хеш-класс, позволяющих сохранять порядок заносимых в него ключей

# SYNOPSIS

    use Clib::DT;
    
    my $h = Clib::Hash->byarray(
                key1 => 'value1', 
                key2 => 'value2'
            );
    
    my $h = Clib::Hash->byref(
                {
                    key1 => 'value1', 
                    key2 => 'value2',
                    ordered_by_keyname_1 => 'value3',
                    ordered_by_keyname_2 => 'value4',
                },
                qw/key1 key2/
            );
