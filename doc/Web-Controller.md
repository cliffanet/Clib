# NAME

Clib::Web::Controller - HTTP-контроллер, позволяющий делать из структуры pm-модулей и функций в ник формировать красивые URL.

# SYNOPSIS

    use Clib::Web::Controller;

    webctrl_local(
            'CMain',
            attr => [qw/Title ReturnDebug ReturnText/],
            eval => "
                use Clib::Const;
                use Clib::Log;
            
                *wparam = *WebMain::param;
            ",
        ) || die webctrl_error;


    package CMain::Load;
    
    sub _root :
            ParamUInt
            ReturnText
    {
        return 'OK';
    }
    
    sub form :
            ParamUInt
    {
        my $id = shift();
        return 'form';
    }

Указанный пример сформирует пути:

- `/load` - обработчик: функция CMain::Load::\_root()
- `/load/XXX/form` - обработчик: функция CMain::Load::form()

    При вызове этой функции будет передан аргумент со значением XXX из URL.

    Для данного URL XXX может состоять только из цифр.

# Принцип

Вся ветка модулей, начинающихся на `CMain` (из примера) будет просканирована.
Все фукнции с аттрибутами станут обработчиками URL, которые формируются исходя из пути к этой функции.

Например, для пути к функции `CMain::Load::_root()` действуют правила:

- Префикс, указанный как `$srch_class` (в примере: CMain) пропускается.
- Все `::` будут заменены на `/`.
- Имя `_root` (м.б. именем модуля или функции) пропускается.
- Стандартные атрибуты `ParamXXX` дописываются в конце пути перед именем функции в порядке их указания.

# Методы

## new()

Возвращает экземпляр объекта. Аргументов вызова нет.

## error()

Возвращает ошибку, которая возникла при работе с этим объектом.

## local($srch\_class, ...)

Добавляет в данный объект локальную ветку модулей, название которых начинается на $srch\_class

Доп параметры вызова:

- `attr` - список особых допустимых аттрибутов функций-обработчиков.
- `eval` - perl-код, который будет выполнен для каждого найденного модуля.

    Позволяет не дублировать один и тот же код во всех модулях контроллера.

## search($path)

Ищет нужный обработчик по запрашиваемому URL.

## bypath($path)

Если HTTP-контроллер использует только простые пути без доп. аргументов (нет тэгов ParamXXX),
то поиск через `bypath` будет более быстрым, т.к. обращается сразу по ссылке и не перебирает
все ссылки по регулярным выражениям.

## pref($path, @arg)

Возвращает ссылку с собранными в неё значениями аргументов.

При вызове в $path все места, где должны быть аргументы вызова, должны быть пропущены.

Например, если у нас такой обработчик:

    package CMain::Load;
    
    sub form :
            ParamUInt
    {
        my $id = shift();
        return 'form';
    }

Мы можем вызвать:

    my $href = $ctrl->pref('load/form', 123);
    #
    #   $href будет содержать:
    #
    #       /load/123/form
    #

## do($disp, @param)

Вызывает найденный с помощью search() обработчик:

    my $url = '/load/123/form';
    
    my ($disp, @webp) = $ctrl->search($url);
    my @ret = $ctrl->do($disp, @webp);

В `@ret` будет то, что вернула функция `CMain::Load::form()`

# Статичные функции

Модуль импортирует несколько статичных функций для быстрого поиска модулей, если не требуется несколько
веток

Все они начинаются с префикса `webctrl_`. Например:

    webctrl_local($dir, ...);

Вызов этих функций работает с одним и тем же объектом, вызванным глобально.

# Стандартные аттрибуты функций контроллера

## Simple

Обозначает функцию-обработчик, которому не нужны никакие специфичные атрибуты.

## Name

Переопределяет имя функции

## Param

Любой аргумент. В любом случае у аргумента, встраимого в URL, всегда есть минимальные правила:
отсутствие пробелов, спецсимволов и всего, что недопустимо использовать в основной части URL

## ParamRegexp

Аргумент, соответствующий регулярному выражению.

## ParamInt

Аргумент - любое число

## ParamUInt

Аргумент - любое положительное число

## ParamCode

Аргумент, который будет обработан функцией.

    package CMain::Load;
    
    sub byId {
        my $id = shift();
        return find_rec_by_id($id);
    }
    
    sub form :
            ParamCode(\&byId)
    {
        my $rec = shift();
        return 'form';
    }

Тут в form() будет передан уже не `$id`, а `$rec`, полученная в `byId()`.

## ParamCodeInt

Аргумент - любое число, обработанное функцией.

## ParamCodeUInt

Аргумент - любое положительное число, обработанное функцией.

## ParamWord

Аргумент - любое слово. Допустимые символы: a-z, A-Z, 0-9, \_ и -.

## ParamEnd

Сообщает, чтобы в URL аргументы все шли в самом конце, после имени функции.