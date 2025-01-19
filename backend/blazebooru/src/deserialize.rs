use std::{
    fmt::{self, Display},
    marker::PhantomData,
    str::FromStr,
};

use serde::{
    de::{self, Visitor},
    Deserializer,
};

pub fn comma_separated<'de, V, T, D>(deserializer: D) -> Result<V, D::Error>
where
    V: FromIterator<T>,
    T: FromStr,
    T::Err: Display,
    D: Deserializer<'de>,
{
    struct Delimited<V, T>(PhantomData<V>, PhantomData<T>);

    impl<V, T> Visitor<'_> for Delimited<V, T>
    where
        V: FromIterator<T>,
        T: FromStr,
        T::Err: Display,
    {
        type Value = V;

        fn expecting(&self, formatter: &mut fmt::Formatter) -> fmt::Result {
            formatter.write_str("comma-separated list")
        }

        fn visit_str<E>(self, s: &str) -> Result<Self::Value, E>
        where
            E: de::Error,
        {
            let iter = s.split(',').map(FromStr::from_str);
            Result::from_iter(iter).map_err(de::Error::custom)
        }
    }

    let visitor = Delimited(PhantomData, PhantomData);
    deserializer.deserialize_str(visitor)
}
