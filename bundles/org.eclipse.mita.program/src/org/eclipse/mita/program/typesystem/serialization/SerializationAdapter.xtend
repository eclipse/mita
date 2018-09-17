package org.eclipse.mita.program.typesystem.serialization

import com.google.gson.GsonBuilder
import com.google.gson.JsonDeserializationContext
import com.google.gson.JsonDeserializer
import com.google.gson.JsonElement
import com.google.gson.JsonObject
import com.google.gson.JsonParseException
import com.google.gson.JsonSerializationContext
import com.google.gson.JsonSerializer
import com.google.inject.Inject
import com.google.inject.Provider
import java.lang.reflect.Type
import org.eclipse.emf.common.util.URI
import org.eclipse.emf.ecore.EClass
import org.eclipse.emf.ecore.EPackage
import org.eclipse.emf.ecore.EReference
import org.eclipse.emf.ecore.EcoreFactory
import org.eclipse.emf.ecore.impl.BasicEObjectImpl
import org.eclipse.emf.ecore.util.EcoreUtil
import org.eclipse.mita.base.typesystem.constraints.AbstractTypeConstraint
import org.eclipse.mita.base.typesystem.constraints.EqualityConstraint
import org.eclipse.mita.base.typesystem.constraints.ExplicitInstanceConstraint
import org.eclipse.mita.base.typesystem.constraints.FunctionTypeClassConstraint
import org.eclipse.mita.base.typesystem.constraints.SubtypeConstraint
import org.eclipse.mita.base.typesystem.constraints.TypeClassConstraint
import org.eclipse.mita.base.typesystem.infra.TypeClass
import org.eclipse.mita.base.typesystem.infra.TypeVariableProxy
import org.eclipse.mita.base.typesystem.serialization.SerializedAbstractBaseType
import org.eclipse.mita.base.typesystem.serialization.SerializedAbstractType
import org.eclipse.mita.base.typesystem.serialization.SerializedAbstractTypeConstraint
import org.eclipse.mita.base.typesystem.serialization.SerializedAtomicType
import org.eclipse.mita.base.typesystem.serialization.SerializedBaseKind
import org.eclipse.mita.base.typesystem.serialization.SerializedBottomType
import org.eclipse.mita.base.typesystem.serialization.SerializedCoSumType
import org.eclipse.mita.base.typesystem.serialization.SerializedConstraintSystem
import org.eclipse.mita.base.typesystem.serialization.SerializedEReference
import org.eclipse.mita.base.typesystem.serialization.SerializedEqualityConstraint
import org.eclipse.mita.base.typesystem.serialization.SerializedExplicitInstanceConstraint
import org.eclipse.mita.base.typesystem.serialization.SerializedFloatingType
import org.eclipse.mita.base.typesystem.serialization.SerializedFunctionType
import org.eclipse.mita.base.typesystem.serialization.SerializedFunctionTypeClassConstraint
import org.eclipse.mita.base.typesystem.serialization.SerializedIntegerType
import org.eclipse.mita.base.typesystem.serialization.SerializedObject
import org.eclipse.mita.base.typesystem.serialization.SerializedProductType
import org.eclipse.mita.base.typesystem.serialization.SerializedSubtypeConstraint
import org.eclipse.mita.base.typesystem.serialization.SerializedSumType
import org.eclipse.mita.base.typesystem.serialization.SerializedTypeClass
import org.eclipse.mita.base.typesystem.serialization.SerializedTypeConstructorType
import org.eclipse.mita.base.typesystem.serialization.SerializedTypeScheme
import org.eclipse.mita.base.typesystem.serialization.SerializedTypeVariable
import org.eclipse.mita.base.typesystem.serialization.SerializedTypeVariableProxy
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.types.AbstractBaseType
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.AtomicType
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
import org.eclipse.xtext.naming.QualifiedName

import static extension org.eclipse.mita.base.util.BaseUtils.force

class SerializationAdapter {
	
	@Inject 
	protected Provider<ConstraintSystem> constraintSystemProvider; 
		
	def fromJSON(String json) {
		 return new GsonBuilder()
    		.registerTypeHierarchyAdapter(SerializedObject, new MitaJsonSerializer())
    		.create()
    		.fromJson(json, SerializedObject)
    		.fromValueObject() as ConstraintSystem;
	}
	protected dispatch def EReference fromValueObject(SerializedEReference obj) {
		val Class<EPackage> clazz = Class.forName(obj.javaClass) as Class<EPackage>;
		val member = clazz.getField(obj.javaField).get(null);
		val method = clazz.getDeclaredMethod(obj.javaMethod);
		val result = method.invoke(member);
		return result as EReference;
	}
	
	protected dispatch def ConstraintSystem fromValueObject(SerializedConstraintSystem obj) {
		val result = constraintSystemProvider.get();
		obj.constraints.map[ it.fromValueObject() as AbstractTypeConstraint ].forEach[ result.addConstraint(it) ];
		result.typeClasses.putAll(obj
			.typeClasses
			.entrySet
			.map[ it.key.toQualifiedName -> it.value.fromValueObject() as TypeClass ]
			.toMap([ it.key ], [ it.value ])
		);
		return result;
	}
	
	protected dispatch def EqualityConstraint fromValueObject(SerializedEqualityConstraint obj) {
		return new EqualityConstraint(obj.left.fromValueObject() as AbstractType, obj.right.fromValueObject() as AbstractType, obj.source);
	}
	
	protected dispatch def ExplicitInstanceConstraint fromValueObject(SerializedExplicitInstanceConstraint obj) {
		return new ExplicitInstanceConstraint(obj.instance.fromValueObject() as AbstractType, obj.typeScheme.fromValueObject() as AbstractType)
	}
	
	protected dispatch def SubtypeConstraint fromValueObject(SerializedSubtypeConstraint obj) {
		return new SubtypeConstraint(obj.subType.fromValueObject() as AbstractType, obj.superType.fromValueObject() as AbstractType)
	}
	
	protected dispatch def TypeClassConstraint fromValueObject(SerializedFunctionTypeClassConstraint obj) {
		return new FunctionTypeClassConstraint(obj.type.fromValueObject() as AbstractType, obj.instanceOfQN.toQualifiedName, obj.functionCall.toEObjectProxy, null, obj.returnTypeTV.fromValueObject as TypeVariable, null);
	}
	
	protected dispatch def AbstractType fromValueObject(SerializedAtomicType obj) {
		return new AtomicType(obj.origin.toEObjectProxy(), obj.name);
	}
	
	protected dispatch def AbstractType fromValueObject(SerializedBaseKind obj) {
		return new BaseKind(obj.origin.toEObjectProxy(), obj.name, obj.kindOf.fromValueObject() as AbstractType);
	}
	
	protected dispatch def AbstractType fromValueObject(SerializedBottomType obj) {
		return new BottomType(obj.origin.toEObjectProxy(), obj.name, obj.message);
	}
	
	protected dispatch def AbstractType fromValueObject(SerializedFloatingType obj) {
		return new FloatingType(obj.origin.toEObjectProxy(), obj.widthInBytes);
	}
	
	protected dispatch def AbstractType fromValueObject(SerializedIntegerType obj) {
		return new IntegerType(obj.origin.toEObjectProxy(), obj.widthInBytes, obj.signedness);
	}
	
	protected dispatch def AbstractType fromValueObject(SerializedFunctionType obj) {
		return new FunctionType(
			obj.origin.toEObjectProxy(),
			obj.name,
			obj.typeArguments.fromSerializedTypes(),
			obj.superTypes.fromSerializedTypes(),
			obj.from.fromValueObject() as AbstractType,
			obj.to.fromValueObject() as AbstractType
		);
	}
	
	protected dispatch def AbstractType fromValueObject(SerializedProductType obj) {
		return new ProdType(obj.origin.toEObjectProxy(), obj.name, obj.typeArguments.fromSerializedTypes(), obj.superTypes.fromSerializedTypes());
	}
	
	protected dispatch def AbstractType fromValueObject(SerializedCoSumType obj) {
		return new CoSumType(obj.origin.toEObjectProxy(), obj.name, obj.typeArguments.fromSerializedTypes(), obj.superTypes.fromSerializedTypes());
	}
	
	protected dispatch def AbstractType fromValueObject(SerializedSumType obj) {
		return new SumType(obj.origin.toEObjectProxy(), obj.name, obj.typeArguments.fromSerializedTypes(), obj.superTypes.fromSerializedTypes());
	}
	
	protected dispatch def AbstractType fromValueObject(SerializedTypeConstructorType obj) {
		return new TypeConstructorType(obj.origin.toEObjectProxy(), obj.name, obj.typeArguments.fromSerializedTypes(), obj.superTypes.fromSerializedTypes());
	}
	
	protected dispatch def AbstractType fromValueObject(SerializedTypeScheme obj) {
		return new TypeScheme(obj.origin.toEObjectProxy(), obj.vars.map[ it.fromValueObject() as TypeVariable ].toList(), obj.on.fromValueObject() as AbstractType);
	}
	
	protected dispatch def AbstractType fromValueObject(SerializedTypeVariable obj) {
		return new TypeVariable(obj.origin.toEObjectProxy(), obj.name);
	}
	
	protected dispatch def AbstractType fromValueObject(SerializedTypeVariableProxy obj) {
		return new TypeVariableProxy(obj.origin.toEObjectProxy(), obj.name, obj.reference.fromValueObject as EReference, obj.targetQID.toQualifiedName);
	}
	
	protected def Iterable<AbstractType> fromSerializedTypes(Iterable<SerializedAbstractType> obj) {
		return obj.map[ it.fromValueObject() as AbstractType ].toList();
	}
	
	protected def toEObjectProxy(String uri) {
		return if(uri !== null) EcoreFactory.eINSTANCE.createEObject() => [ (it as BasicEObjectImpl).eSetProxyURI(URI.createURI(uri)) ];
	}
	
	protected def toQualifiedName(String fqn) {
		return QualifiedName.create(fqn.split('\\.'))
	}
	
	def toJSON(ConstraintSystem system) {
		val gson = new GsonBuilder()
    		.create();
		return gson.toJson(system.toValueObject());
	}
	
	protected dispatch def SerializedObject toValueObject(EReference reference) {
		return new SerializedEReference => [
			javaClass = (reference.eContainer as EClass).EPackage.nsURI + "." + (reference.eContainer as EClass).EPackage.name.toFirstUpper + "Package";
			javaField = "eINSTANCE";
			javaMethod = "get" + reference.containerClass.simpleName + "_" + reference.name.toFirstUpper;
		]
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
			source = obj.source
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
	
	/*
	 * val EObject functionCall;
	val EReference functionReference;
	val TypeVariable returnTypeTV;
	 */
	protected dispatch def SerializedObject toValueObject(FunctionTypeClassConstraint obj) {
		new SerializedFunctionTypeClassConstraint => [
			type = obj.typ.toValueObject as SerializedAbstractType
			functionCall = if(obj.functionCall === null) null else EcoreUtil.getURI(obj.functionCall).toString();
			functionReference = obj.functionReference.toValueObject;
			returnTypeTV = obj.returnTypeTV.toValueObject as SerializedTypeVariable;
			instanceOfQN = obj.instanceOfQN.toString()
		]
	}
	
//	protected dispatch def SerializedObject toValueObject(TypeConstructorType obj) {
//		new SerializedTypeConstructorType => [
//			name = obj.name;
//			origin = if(obj.origin === null) null else EcoreUtil.getURI(obj.origin).toString();
//			typeArguments = obj.typeArguments.map[it.toValueObject as SerializedAbstractType].force;
//			// TODO: get these translated: superTypes = 
//		]
//	}
	
	protected dispatch def SerializedObject toValueObject(TypeClass obj) {
		new SerializedTypeClass => [
			instances = obj.instances.entrySet
				.map[ it.key.toValueObject as SerializedAbstractType -> it.value.toValueObject ]
				.toMap([ it.key ], [ it.value ])
		]
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
	protected dispatch def SerializedObject toValueObject(AtomicType obj) {
		new SerializedAtomicType => [
			fill(it, obj)
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
	
	protected dispatch def SerializedObject toValueObject(TypeConstructorType obj) {
		new SerializedTypeConstructorType => [
			fill(it, obj)
		]
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
			it.reference = obj.reference?.toValueObject;
			it.targetQID = obj.targetQID.toString;
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
        	
			var clasz = Class.forName(/*this.class.package.name + */'org.eclipse.mita.base.typesystem.serialization.' + type);
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