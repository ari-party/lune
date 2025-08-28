#![allow(clippy::cargo_common_metadata)]

use std::sync::OnceLock;

use mlua::prelude::*;
use mlua_luau_scheduler::LuaSpawnExt;

use lune_roblox::{
    document::{Document, DocumentError, DocumentFormat, DocumentKind},
    instance::{Instance, registry::InstanceRegistry},
    reflection::Database as ReflectionDatabase,
};

static REFLECTION_DATABASE: OnceLock<ReflectionDatabase> = OnceLock::new();

use lune_utils::TableBuilder;
use roblox_install::RobloxStudio;

const TYPEDEFS: &str = include_str!(concat!(env!("CARGO_MANIFEST_DIR"), "/types.d.luau"));

/**
    Returns a string containing type definitions for the `roblox` standard library.
*/
#[must_use]
pub fn typedefs() -> String {
    TYPEDEFS.to_string()
}

/**
    Creates the `roblox` standard library module.

    # Errors

    Errors when out of memory.
*/
pub fn module(lua: Lua) -> LuaResult<LuaTable> {
    let mut roblox_constants = Vec::new();

    let roblox_module = lune_roblox::module(lua.clone())?;
    for pair in roblox_module.pairs::<LuaValue, LuaValue>() {
        roblox_constants.push(pair?);
    }

    let table = TableBuilder::new(lua.clone())?
        .with_values(roblox_constants)?
        .with_async_function("deserializePlace", deserialize_place)?
        .with_async_function("deserializeModel", deserialize_model)?
        .with_async_function("serializePlace", serialize_place)?
        .with_async_function("serializeModel", serialize_model)?
        .with_function("getAuthCookie", get_auth_cookie)?
        .with_function("getReflectionDatabase", get_reflection_database)?
        .with_function("implementProperty", implement_property)?
        .with_function("implementMethod", implement_method)?
        .with_function("studioApplicationPath", studio_application_path)?
        .with_function("studioContentPath", studio_content_path)?
        .with_function("studioPluginPath", studio_plugin_path)?
        .with_function("studioBuiltinPluginPath", studio_builtin_plugin_path)?
        .build_readonly()?;

    implement_byte_size_for_all_classes(&lua, ())?;

    Ok(table)
}

async fn deserialize_place(lua: Lua, contents: LuaString) -> LuaResult<LuaValue> {
    let bytes = contents.as_bytes().to_vec();
    let fut = lua.spawn_blocking(move || {
        let doc = Document::from_bytes(bytes, DocumentKind::Place)?;
        let data_model = doc.into_data_model_instance()?;
        Ok::<_, DocumentError>(data_model)
    });
    fut.await.into_lua_err()?.into_lua(&lua)
}

async fn deserialize_model(lua: Lua, contents: LuaString) -> LuaResult<LuaValue> {
    let bytes = contents.as_bytes().to_vec();
    let fut = lua.spawn_blocking(move || {
        let doc = Document::from_bytes(bytes, DocumentKind::Model)?;
        let instance_array = doc.into_instance_array()?;
        Ok::<_, DocumentError>(instance_array)
    });
    fut.await.into_lua_err()?.into_lua(&lua)
}

async fn serialize_place(
    lua: Lua,
    (data_model, as_xml): (LuaUserDataRef<Instance>, Option<bool>),
) -> LuaResult<LuaString> {
    let data_model = *data_model;
    let fut = lua.spawn_blocking(move || {
        let doc = Document::from_data_model_instance(data_model)?;
        let bytes = doc.to_bytes_with_format(match as_xml {
            Some(true) => DocumentFormat::Xml,
            _ => DocumentFormat::Binary,
        })?;
        Ok::<_, DocumentError>(bytes)
    });
    let bytes = fut.await.into_lua_err()?;
    lua.create_string(bytes)
}

async fn serialize_model(
    lua: Lua,
    (instances, as_xml): (Vec<LuaUserDataRef<Instance>>, Option<bool>),
) -> LuaResult<LuaString> {
    let instances = instances.iter().map(|i| **i).collect();
    let fut = lua.spawn_blocking(move || {
        let doc = Document::from_instance_array(instances)?;
        let bytes = doc.to_bytes_with_format(match as_xml {
            Some(true) => DocumentFormat::Xml,
            _ => DocumentFormat::Binary,
        })?;
        Ok::<_, DocumentError>(bytes)
    });
    let bytes = fut.await.into_lua_err()?;
    lua.create_string(bytes)
}

fn get_auth_cookie(_: &Lua, raw: Option<bool>) -> LuaResult<Option<String>> {
    if matches!(raw, Some(true)) {
        Ok(rbx_cookie::get_value())
    } else {
        Ok(rbx_cookie::get())
    }
}

fn get_reflection_database(_: &Lua, _: ()) -> LuaResult<ReflectionDatabase> {
    Ok(*REFLECTION_DATABASE.get_or_init(ReflectionDatabase::new))
}

fn implement_property(
    lua: &Lua,
    (class_name, property_name, property_getter, property_setter): (
        String,
        String,
        LuaFunction,
        Option<LuaFunction>,
    ),
) -> LuaResult<()> {
    let property_setter = if let Some(setter) = property_setter {
        setter
    } else {
        let property_name = property_name.clone();
        lua.create_function(move |_, _: LuaMultiValue| {
            Err::<(), _>(LuaError::runtime(format!(
                "Property '{property_name}' is read-only"
            )))
        })?
    };
    InstanceRegistry::insert_property_getter(lua, &class_name, &property_name, property_getter)
        .into_lua_err()?;
    InstanceRegistry::insert_property_setter(lua, &class_name, &property_name, property_setter)
        .into_lua_err()?;
    Ok(())
}

fn implement_method(
    lua: &Lua,
    (class_name, method_name, method): (String, String, LuaFunction),
) -> LuaResult<()> {
    InstanceRegistry::insert_method(lua, &class_name, &method_name, method).into_lua_err()?;
    Ok(())
}

fn studio_application_path(_: &Lua, _: ()) -> LuaResult<String> {
    RobloxStudio::locate()
        .map(|rs| rs.application_path().display().to_string())
        .map_err(LuaError::external)
}

fn studio_content_path(_: &Lua, _: ()) -> LuaResult<String> {
    RobloxStudio::locate()
        .map(|rs| rs.content_path().display().to_string())
        .map_err(LuaError::external)
}

fn studio_plugin_path(_: &Lua, _: ()) -> LuaResult<String> {
    RobloxStudio::locate()
        .map(|rs| rs.plugins_path().display().to_string())
        .map_err(LuaError::external)
}

fn studio_builtin_plugin_path(_: &Lua, _: ()) -> LuaResult<String> {
    RobloxStudio::locate()
        .map(|rs| rs.built_in_plugins_path().display().to_string())
        .map_err(LuaError::external)
}

fn implement_byte_size_property(lua: &Lua, (class_name,): (String,)) -> LuaResult<()> {
    let property_name = "ByteSize";

    let getter = lua.create_function(move |_lua, instance: LuaUserDataRef<Instance>| {
        let instance = *instance;

        let doc = if instance.get_class_name() == "DataModel" {
            match lune_roblox::document::Document::from_data_model_instance(instance) {
                Ok(doc) => doc,
                Err(_) => return Ok(0u64),
            }
        } else {
            match lune_roblox::document::Document::from_instance_array(vec![instance]) {
                Ok(doc) => doc,
                Err(_) => return Ok(0u64),
            }
        };

        match doc.to_bytes_with_format(lune_roblox::document::DocumentFormat::Binary) {
            Ok(bytes) => Ok(bytes.len() as u64),
            Err(_) => Ok(0u64),
        }
    })?;

    let setter = lua.create_function(move |_, _: LuaMultiValue| {
        Err::<(), _>(LuaError::runtime(format!(
            "Property '{}' is read-only",
            property_name
        )))
    })?;

    InstanceRegistry::insert_property_getter(lua, &class_name, property_name, getter)
        .into_lua_err()?;
    InstanceRegistry::insert_property_setter(lua, &class_name, property_name, setter)
        .into_lua_err()?;

    Ok(())
}

fn implement_byte_size_for_all_classes(lua: &Lua, _: ()) -> LuaResult<()> {
    let db = lune_roblox::reflection::Database::new();

    for class_name in db.get_class_names() {
        let class_name_for_call = class_name.clone();
        let class_name_for_error = class_name.clone();
        if let Err(e) = implement_byte_size_property(lua, (class_name_for_call,)) {
            eprintln!(
                "Failed to implement ByteSize for class {}: {}",
                class_name_for_error, e
            );
        }
    }

    Ok(())
}
