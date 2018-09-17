package org.eclipse.mita.base.typesystem.serialization

import com.google.gson.Gson
import com.google.gson.GsonBuilder
import com.google.gson.JsonDeserializationContext
import com.google.gson.JsonDeserializer
import com.google.gson.JsonElement
import com.google.gson.JsonObject
import com.google.gson.JsonParseException
import com.google.gson.JsonSerializationContext
import com.google.gson.JsonSerializer
import java.lang.reflect.Type
import org.eclipse.emf.ecore.util.EcoreUtil
import org.eclipse.mita.base.typesystem.constraints.EqualityConstraint
import org.eclipse.mita.base.typesystem.constraints.ExplicitInstanceConstraint
import org.eclipse.mita.base.typesystem.constraints.SubtypeConstraint
import org.eclipse.mita.base.typesystem.constraints.TypeClassConstraint
import org.eclipse.mita.base.typesystem.infra.TypeClass
import org.eclipse.mita.base.typesystem.infra.TypeVariableProxy
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.types.AbstractBaseType
import org.eclipse.mita.base.typesystem.types.BaseKind
import org.eclipse.mita.base.typesystem.types.BottomType
import org.eclipse.mita.base.typesystem.types.CoSumType
import org.eclipse.mita.base.typesystem.types.FloatingType
import org.eclipse.mita.base.typesystem.types.FunctionType
import org.eclipse.mita.base.typesystem.types.IntegerType
import org.eclipse.mita.base.typesystem.types.ProdType
import org.eclipse.mita.base.typesystem.types.SumType
import org.eclipse.mita.base.typesystem.types.TypeConstructorType
import org.eclipse.mita.base.typesystem.types.TypeScheme
import org.eclipse.mita.base.typesystem.types.TypeVariable

import static extension org.eclipse.mita.base.util.BaseUtils.force

class SerializationAdapter {
	
	def toJSON(ConstraintSystem system) {
		val gson = new Gson();
		return gson.toJson(system.toValueObject());
	}
	
	def fromJSON(String json) {
		 return new GsonBuilder()
    		.registerTypeHierarchyAdapter(SerializedObject, new MitaJsonSerializer())
    		.create()
    		.fromJson(json, SerializedObject);
	}
	
	protected dispatch def SerializedObject toValueObject(ConstraintSystem obj) {
		new SerializedConstraintSystem => [
			constraints = obj.constraints.map[ it.toValueObject() as SerializedAbstractTypeConstraint ]
			typeClasses = obj.typeClasses
				.entrySet
				.map[ it.key.toString() -> it.value.toValueObject as SerializedTypeClass ]
				.toMap([ it.key ], [ it.value ]);
		]
	}
	
	protected dispatch def SerializedObject toValueObject(EqualityConstraint obj) {
		new SerializedEqualityConstraint => [
			left = obj.left.toValueObject as SerializedAbstractType
			right = obj.right.toValueObject as SerializedAbstractType
		]
	}
	
	protected dispatch def SerializedObject toValueObject(ExplicitInstanceConstraint obj) {
		new SerializedExplicitInstanceConstraint => [
			instance = obj.instance.toValueObject as SerializedAbstractType
			typeScheme = obj.typeScheme.toValueObject as SerializedAbstractType
		]
	}
	
	protected dispatch def SerializedObject toValueObject(SubtypeConstraint obj) {
		new SerializedSubtypeConstraint => [
			subType = obj.subType.toValueObject as SerializedAbstractType
			superType = obj.superType.toValueObject as SerializedAbstractType
		]
	}
	
	protected dispatch def SerializedObject toValueObject(TypeClassConstraint obj) {
		new SerializedTypeclassConstraint => [
			type = obj.typ.toValueObject as SerializedAbstractType
			instanceOfQN = obj.instanceOfQN.toString()
		]
	}
	
	protected dispatch def SerializedObject toValueObject(TypeConstructorType obj) {
		new SerializedTypeConstructorType => [
			name = obj.name;
			origin = if(obj.origin === null) null else EcoreUtil.getURI(obj.origin).toString();
			typeArguments = obj.typeArguments.map[it.toValueObject as SerializedAbstractType].force;
			// TODO: get these translated superTypes = 
		]
	}
	
	protected dispatch def SerializedObject toValueObject(TypeClass obj) {
		new SerializedTypeClass => [
			instances = obj.instances.entrySet
				.map[ it.key.toValueObject as SerializedAbstractType -> it.value.toValueObject ]
				.toMap([ it.key ], [ it.value ])
		]
	}
	
	protected dispatch def SerializedObject toValueObject(AbstractBaseType obj) {
		new SerializedAbstractBaseType => [ fill(it, obj) ]
	}
	
	protected dispatch def Object fill(SerializedAbstractBaseType ctxt, AbstractBaseType obj) {
		ctxt.name = obj.name;
		ctxt.origin = if(obj.origin === null) null else EcoreUtil.getURI(obj.origin).toString()
		return ctxt;
	}
	
	protected dispatch def Object fill(SerializedTypeVariable ctxt, TypeVariable obj) {
		ctxt.name = obj.name;
		ctxt.origin = if(obj.origin === null) null else EcoreUtil.getURI(obj.origin).toString()
		return ctxt;
	}
	
	protected dispatch def SerializedObject toValueObject(BaseKind obj) {
		new SerializedBaseKind => [
			fill(it, obj)
			kindOf = obj.kindOf.toValueObject as SerializedAbstractType
		]
	}
	
	protected dispatch def SerializedObject toValueObject(BottomType obj) {
		new SerializedBottomType => [
			fill(it, obj)
			message = message
		]
	}
	
	protected dispatch def SerializedObject toValueObject(FloatingType obj) {
		new SerializedFloatingType => [
			fill(it, obj)
			widthInBytes = obj.widthInBytes
		]
	}
	
	protected dispatch def SerializedObject toValueObject(IntegerType obj) {
		new SerializedIntegerType => [
			fill(it, obj)
			widthInBytes = obj.widthInBytes
			signedness = obj.signedness
		]
	}
	
	protected dispatch def Object fill(SerializedTypeConstructorType ctxt, TypeConstructorType obj) {
		ctxt.name = obj.name
		ctxt.origin = if(obj.origin === null) null else EcoreUtil.getURI(obj.origin).toString()
		ctxt.typeArguments = obj.typeArguments.map[ it.toValueObject as SerializedAbstractType ].toList
		ctxt.superTypes = obj.superTypes.map[ it.toValueObject as SerializedAbstractType ].toList
		return ctxt
	}
	
	protected dispatch def Object fill(SerializedTypeScheme ctxt, TypeScheme obj) {
		ctxt.name = obj.name;
		ctxt.vars = obj.vars.map[ it.toValueObject as SerializedTypeVariable ].force;
		ctxt.on = obj.on.toValueObject as SerializedAbstractType;
		ctxt.origin = if(obj.origin === null) null else EcoreUtil.getURI(obj.origin).toString()
		return ctxt;
	}
	
	protected dispatch def SerializedObject toValueObject(FunctionType obj) {
		new SerializedFunctionType => [
			fill(it, obj)
			from = obj.from.toValueObject as SerializedAbstractType
			to = obj.to.toValueObject as SerializedAbstractType
		]
	}
	
	protected dispatch def SerializedObject toValueObject(ProdType obj) {
		new SerializedProductType => [ fill(it, obj) ]
	}
	
	protected dispatch def SerializedObject toValueObject(CoSumType obj) {
		new SerializedCoSumType => [ fill(it, obj) ]
	}
	
	protected dispatch def SerializedObject toValueObject(SumType obj) {
		new SerializedSumType => [ fill(it, obj) ]
	}
	
	protected dispatch def SerializedObject toValueObject(TypeScheme obj) {
		new SerializedTypeScheme => [
			fill(it, obj)
			on = obj.on.toValueObject as SerializedAbstractType
			vars = obj.vars.map[ it.toValueObject as SerializedTypeVariable ].toList
		]
	}
	
	protected dispatch def SerializedObject toValueObject(TypeVariable obj) {
		new SerializedTypeVariable => [
			fill(it, obj)
		]
	}
	
	protected dispatch def SerializedObject toValueObject(TypeVariableProxy obj) {
		new SerializedTypeVariableProxy => [
			fill(it, obj)
			it.reference = obj.reference.name;
			it.qualifiedName = obj.qualifiedName;
		]
	}
	

	protected static class MitaJsonSerializer implements JsonSerializer<SerializedObject>, JsonDeserializer<SerializedObject> {
		
		override serialize(SerializedObject src, Type typeOfSrc, JsonSerializationContext context) {
			val result = context.serialize(src);
			if(result instanceof JsonObject) {
				result.addProperty("__type", src.class.name);
			}
			return result;
		}
		
		override deserialize(JsonElement json, Type typeOfT, JsonDeserializationContext context) throws JsonParseException {
			val jsonObject = json.getAsJsonObject();
        	val type = jsonObject.get("_type").asString;
        	
			var clasz = Class.forName(this.class.package.name + '.' + type);
			val result = clasz.getConstructor().newInstance();
			while(clasz !== null) {
		        for (field : clasz.getFields()) {
		            if(jsonObject.has(field.getName())) {
		            	val rawFieldValue = jsonObject.get(field.getName());
		            	val fieldValue = context.deserialize(rawFieldValue, field.getGenericType());
		                field.set(result, fieldValue);
		            }
		        }
				clasz = clasz.superclass;				
			}
			return result as SerializedObject;
		}
		
	}
	
}