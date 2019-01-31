package org.eclipse.mita.base.typesystem.serialization

import com.google.gson.JsonDeserializationContext
import com.google.gson.JsonDeserializer
import com.google.gson.JsonElement
import com.google.gson.JsonObject
import com.google.gson.JsonParseException
import com.google.gson.JsonSerializationContext
import com.google.gson.JsonSerializer
import com.google.inject.Inject
import com.google.inject.Provider
import io.protostuff.LinkedBuffer
import io.protostuff.ProtostuffIOUtil
import io.protostuff.Schema
import io.protostuff.runtime.RuntimeSchema
import java.lang.reflect.Type
import java.util.HashMap
import org.eclipse.emf.common.util.URI
import org.eclipse.emf.ecore.EClass
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.EPackage
import org.eclipse.emf.ecore.EReference
import org.eclipse.emf.ecore.EStructuralFeature
import org.eclipse.emf.ecore.EcoreFactory
import org.eclipse.emf.ecore.impl.BasicEObjectImpl
import org.eclipse.emf.ecore.util.EcoreUtil
import org.eclipse.mita.base.types.validation.IValidationIssueAcceptor.ValidationIssue
import org.eclipse.mita.base.typesystem.constraints.AbstractTypeConstraint
import org.eclipse.mita.base.typesystem.constraints.EqualityConstraint
import org.eclipse.mita.base.typesystem.constraints.ExplicitInstanceConstraint
import org.eclipse.mita.base.typesystem.constraints.FunctionTypeClassConstraint
import org.eclipse.mita.base.typesystem.constraints.JavaClassInstanceConstraint
import org.eclipse.mita.base.typesystem.constraints.SubtypeConstraint
import org.eclipse.mita.base.typesystem.constraints.TypeClassConstraint
import org.eclipse.mita.base.typesystem.infra.Graph
import org.eclipse.mita.base.typesystem.infra.TypeClass
import org.eclipse.mita.base.typesystem.infra.TypeClassProxy
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.AtomicType
import org.eclipse.mita.base.typesystem.types.BaseKind
import org.eclipse.mita.base.typesystem.types.BottomType
import org.eclipse.mita.base.typesystem.types.FloatingType
import org.eclipse.mita.base.typesystem.types.FunctionType
import org.eclipse.mita.base.typesystem.types.IntegerType
import org.eclipse.mita.base.typesystem.types.ProdType
import org.eclipse.mita.base.typesystem.types.SumType
import org.eclipse.mita.base.typesystem.types.TypeConstructorType
import org.eclipse.mita.base.typesystem.types.TypeHole
import org.eclipse.mita.base.typesystem.types.TypeScheme
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.mita.base.typesystem.types.TypeVariableProxy
import org.eclipse.mita.base.typesystem.types.UnorderedArguments
import org.eclipse.xtext.naming.QualifiedName

import static extension org.eclipse.mita.base.util.BaseUtils.force
import static extension org.eclipse.mita.base.util.BaseUtils.zip

class SerializationAdapter {
	
	@Inject 
	protected Provider<ConstraintSystem> constraintSystemProvider; 
	
	protected (URI) => EObject objectResolver;
	
	protected LinkedBuffer buffer = LinkedBuffer.allocate(512);
		
	def ConstraintSystem deserializeConstraintSystemFromJSON(String json, (URI)=>EObject objectResolver) {
		val Schema<SerializedConstraintSystem> schema = RuntimeSchema.getSchema(SerializedConstraintSystem);
		this.objectResolver = objectResolver ?: [URI uri| this.toEObjectProxy(uri) ];
		val bytes = json.getBytes("ISO-8859-1");
		val serialized = schema.newMessage();
		ProtostuffIOUtil.mergeFrom(bytes, serialized, schema);
		
		
    	val result = serialized.fromValueObject() as ConstraintSystem;
    	return result;
	}

	protected dispatch def ValidationIssue fromValueObject(SerializedValidationIssue obj) {
		new ValidationIssue(obj.severity, obj.message, obj.target?.resolveEObject(), obj.feature?.fromValueObject as EStructuralFeature, obj.issueCode);
	}
	
	protected dispatch def EReference fromValueObject(SerializedEReference obj) {
		val registry = EPackage.Registry.INSTANCE;
		val ePackage = registry.getEPackage(obj.ePackageName);
		val eClass = ePackage.getEClassifier(obj.eClassName) as EClass;
		val result = eClass.getEStructuralFeature(obj.eReferenceName);
		return result as EReference;
	}
	protected dispatch def EStructuralFeature fromValueObject(SerializedEStructuralFeature obj) {
		val registry = EPackage.Registry.INSTANCE;
		val ePackage = registry.getEPackage(obj.ePackageName);
		val eClass = ePackage.getEClassifier(obj.eClassName) as EClass;
		val result = eClass.getEStructuralFeature(obj.eReferenceName);
		return result as EStructuralFeature;
	}	
	
	protected dispatch def ConstraintSystem fromValueObject(SerializedConstraintSystem obj) {
		val result = constraintSystemProvider.get();
		obj.symbolTable.entrySet.forEach[u_tv | 
			result.symbolTable.put(URI.createURI(u_tv.key), fromValueObject(u_tv.value) as TypeVariable);
		];
		obj.typeTable.entrySet.forEach[u_t | 
			result.typeTable.put(u_t.key.toQualifiedName, fromValueObject(u_t.value) as AbstractType);
		]
		result.typeClasses.putAll(obj
			.typeClasses
			.entrySet
			.map[ it.key.toQualifiedName -> it.value.fromValueObject() as TypeClass ]
			.toMap([ it.key ], [ it.value ])
		);
		obj.constraints.map[ it.fromValueObject() as AbstractTypeConstraint ].forEach[ result.addConstraint(it) ];
		result.constraintSystemProvider = constraintSystemProvider;
		result.explicitSubtypeRelations = obj.explicitSubtypeRelations.fromValueObject() as Graph<AbstractType>;
		result.explicitSubtypeRelationsTypeSource = obj.explicitSubtypeRelationsTypeSource.entrySet.toMap(
			[it.key], [it.value.fromValueObject as AbstractType]
		)
		result.userData = new HashMap(obj.userData.entrySet.toMap([it.key], [new HashMap(it.value)]));
		return result;
	}
	
	protected dispatch def Graph<AbstractType> fromValueObject(SerializedAbstractTypeGraph obj) {
		new Graph<AbstractType>() => [
			outgoing.putAll(obj.outgoing);
			incoming.putAll(obj.incoming);
			nodeIndex.putAll(obj.nodeIndex.mapValues[it.fromValueObject as AbstractType]);
			nextNodeInt = obj.nextNodeInt;
			computeReverseMap();
		]
	}
		
	protected dispatch def TypeClass fromValueObject(SerializedTypeClass obj) {
		new TypeClass(obj.instances.entrySet.map[
			it.key.fromValueObject as AbstractType -> it.value.resolveEObject(true)
		])
	}
	
	protected dispatch def TypeClassProxy fromValueObject(SerializedTypeClassProxy obj) {
		new TypeClassProxy(obj.toResolve.fromValueObject as TypeVariableProxy);
	}
	
	protected dispatch def JavaClassInstanceConstraint fromValueObject(SerializedJavaClassInstanceConstraint obj) {
		return new JavaClassInstanceConstraint(obj.errorMessage.fromValueObject as ValidationIssue, obj.what.fromValueObject() as AbstractType, Class.forName(obj.javaClass));
	}
	
	protected dispatch def EqualityConstraint fromValueObject(SerializedEqualityConstraint obj) {
		return new EqualityConstraint(obj.left.fromValueObject() as AbstractType, obj.right.fromValueObject() as AbstractType, obj.errorMessage.fromValueObject as ValidationIssue);
	}
	
	protected dispatch def ExplicitInstanceConstraint fromValueObject(SerializedExplicitInstanceConstraint obj) {
		return new ExplicitInstanceConstraint(obj.instance.fromValueObject() as AbstractType, obj.typeScheme.fromValueObject() as AbstractType, obj.errorMessage.fromValueObject as ValidationIssue);
	}
	
	protected dispatch def SubtypeConstraint fromValueObject(SerializedSubtypeConstraint obj) {
		return new SubtypeConstraint(obj.subType.fromValueObject() as AbstractType, obj.superType.fromValueObject() as AbstractType, obj.errorMessage.fromValueObject as ValidationIssue)
	}
	
	protected dispatch def TypeClassConstraint fromValueObject(SerializedFunctionTypeClassConstraint obj) {
		return new FunctionTypeClassConstraint(
			obj.errorMessage.fromValueObject as ValidationIssue,
			obj.type.fromValueObject() as AbstractType,
			obj.instanceOfQN.toQualifiedName, 
			obj.functionCall.resolveEObject(true), 
			obj.functionReference?.fromValueObject as EReference, 
			obj.returnTypeTV.fromValueObject as TypeVariable, 
			obj.returnTypeVariance,
			constraintSystemProvider
		);
	}
	
	protected dispatch def AbstractType fromValueObject(SerializedAtomicType obj) {
		return new AtomicType(obj.origin.resolveEObject(), obj.name);
	}
	
	protected dispatch def AbstractType fromValueObject(SerializedBaseKind obj) {
		return new BaseKind(obj.origin.resolveEObject(), obj.name, obj.kindOf.fromValueObject() as AbstractType);
	}
	
	protected dispatch def AbstractType fromValueObject(SerializedBottomType obj) {
		return new BottomType(obj.origin.resolveEObject(), obj.message);
	}
	
	protected dispatch def AbstractType fromValueObject(SerializedFloatingType obj) {
		return new FloatingType(obj.origin.resolveEObject(), obj.widthInBytes);
	}
	
	protected dispatch def AbstractType fromValueObject(SerializedIntegerType obj) {
		return new IntegerType(obj.origin.resolveEObject(), obj.widthInBytes, obj.signedness);
	}
	
	protected dispatch def AbstractType fromValueObject(SerializedTypeHole obj) {
		return new TypeHole(obj.origin.resolveEObject(), obj.name);
	}
	
	protected dispatch def AbstractType fromValueObject(SerializedFunctionType obj) {
		return new FunctionType(
			obj.origin.resolveEObject(),
			obj.type.fromValueObject as AbstractType,
			obj.typeArguments.fromSerializedTypes()
		);
	}
	
	protected dispatch def AbstractType fromValueObject(SerializedUnorderedArguments obj) {
		return new UnorderedArguments(obj.origin.resolveEObject(), obj.type.fromValueObject as AbstractType, obj.parameterNames.zip(obj.valueTypes.fromSerializedTypes()));
	}
	
	protected dispatch def AbstractType fromValueObject(SerializedProductType obj) {
		return new ProdType(obj.origin.resolveEObject(), obj.type.fromValueObject as AbstractType, obj.typeArguments.fromSerializedTypes());
	}
	
	
	protected dispatch def AbstractType fromValueObject(SerializedSumType obj) {
		return new SumType(obj.origin.resolveEObject(), obj.type.fromValueObject as AbstractType, obj.typeArguments.fromSerializedTypes());
	}
	
	protected dispatch def AbstractType fromValueObject(SerializedTypeConstructorType obj) {
		return new TypeConstructorType(obj.origin.resolveEObject(), obj.type.fromValueObject as AbstractType, obj.typeArguments.fromSerializedTypes());
	}
	
	protected dispatch def AbstractType fromValueObject(SerializedTypeScheme obj) {
		return new TypeScheme(obj.origin.resolveEObject(), obj.vars.map[ it.fromValueObject() as TypeVariable ].toList(), obj.on.fromValueObject() as AbstractType);
	}
	
	protected dispatch def AbstractType fromValueObject(SerializedTypeVariable obj) {
		val origin = obj.origin.resolveEObject();
		return new TypeVariable(origin, obj.name);
	}
	
	protected dispatch def AbstractType fromValueObject(SerializedTypeVariableProxy obj) {
		// we resolve the origin of TypeVarProxies because we pass them to the scope later
		val resolve = obj.reference.eReferenceName != "type";
		val origin = obj.origin.resolveEObject(resolve);
		return new TypeVariableProxy(origin, obj.name, obj.reference.fromValueObject as EReference, obj.targetQID.toQualifiedName, obj.ambiguityResolutionStrategy);
	}
	
	protected def Iterable<AbstractType> fromSerializedTypes(Iterable<SerializedAbstractType> obj) {
		return obj.map[ it.fromValueObject() as AbstractType ].toList();
	}
	
	protected def resolveEObject(String uri) {
		return resolveEObject(uri, false);
	}
	
	protected def resolveEObject(String uri, boolean resolveExternally) {
		return if(uri !== null) {
			val realUri = URI.createURI(uri);
			if(resolveExternally) {
				this.objectResolver.apply(realUri);
			} else {
				this.toEObjectProxy(realUri);
			}
		}
	}
	
	protected def toEObjectProxy(URI uri) {
		return EcoreFactory.eINSTANCE.createEObject() => [ (it as BasicEObjectImpl).eSetProxyURI(uri) ];
	}
	
	protected def toQualifiedName(String fqn) {
		return QualifiedName.create(fqn.split('\\.'))
	}
	
	def String toJSON(ConstraintSystem system) {
//		val gson = new GsonBuilder()
//			.setPrettyPrinting
//    		.create();
//		return gson.toJson(system.toValueObject());

		var byte[] content;
		synchronized(buffer) {
			val schema = RuntimeSchema.getSchema(SerializedConstraintSystem);
			try {
				content = ProtostuffIOUtil.toByteArray(system.toValueObject as SerializedConstraintSystem, schema, buffer);
			}
			finally {
				buffer.clear();
			}
		}
		return new String(content, "ISO-8859-1");		
	}
		
	protected dispatch def Object toValueObject(Object nul) {
		throw new NullPointerException;
	}
	protected dispatch def Object toValueObject(Void nul) {
		return null;
	}
	protected dispatch def Object toValueObject(ValidationIssue issue) {
		return new SerializedValidationIssue => [
			severity = issue.severity;
			message = issue.message;
			issueCode = issue.issueCode;
			target = if(issue.target === null) null else EcoreUtil.getURI(issue.target).toString();
			feature = issue.feature.toValueObject as SerializedFeature;
		]
	}
	protected dispatch def Object toValueObject(EReference reference) {
		return new SerializedEReference => [
			ePackageName = (reference.eContainer as EClass).EPackage.nsURI;
			eClassName = (reference.eContainer as EClass).name;
			eReferenceName = reference.name;
		]
	}
	
	protected dispatch def Object toValueObject(ConstraintSystem obj) {
		new SerializedConstraintSystem => [
			symbolTable = obj.symbolTable
				.entrySet.sortBy[it.key.toString]
				.map[it.key.toString() -> it.value.toValueObject ]
				.toMap([it.key], [it.value])
			typeTable = obj.typeTable
				.entrySet.sortBy[it.key.toString]
				.map[it.key.toString -> it.value.toValueObject  ]
				.toMap([it.key], [it.value])
			constraints = obj.constraints.map[ it.toValueObject() as SerializedAbstractTypeConstraint ].force.toSet.toList
			typeClasses = obj.typeClasses
				.entrySet.sortBy[it.key]
				.map[ it.key.toString() -> it.value.toValueObject ]
				.toMap([ it.key ], [ it.value ]);
			explicitSubtypeRelations = obj.explicitSubtypeRelations.toValueObject as SerializedAbstractTypeGraph
			explicitSubtypeRelationsTypeSource = obj.explicitSubtypeRelationsTypeSource.entrySet.toMap(
				[it.key], [it.value.toValueObject as SerializedAbstractType]
			)
			userData = new HashMap(obj.userData.entrySet.toMap([it.key], [new HashMap(it.value)]));
		]
	}
	
	protected dispatch def Object toValueObject(Graph<AbstractType> obj) {
		new SerializedAbstractTypeGraph => [
			outgoing = obj.outgoing;
			incoming = obj.incoming;
			nodeIndex = obj.nodeIndex.mapValues[it.toValueObject as SerializedAbstractType];
			nextNodeInt = obj.nextNodeInt;
		]
	}
	
	protected dispatch def Object toValueObject(EqualityConstraint obj) {
		new SerializedEqualityConstraint => [
			errorMessage = obj._errorMessage.toValueObject as SerializedValidationIssue
			left = obj.left.toValueObject as SerializedAbstractType
			right = obj.right.toValueObject as SerializedAbstractType
		]
	}
	
	protected dispatch def Object toValueObject(JavaClassInstanceConstraint obj) {
		new SerializedJavaClassInstanceConstraint => [
			errorMessage = obj._errorMessage.toValueObject as SerializedValidationIssue
			what = obj.what.toValueObject as SerializedAbstractType;
			javaClass = obj.javaClass.name;
		]
	}
	
	protected dispatch def Object toValueObject(ExplicitInstanceConstraint obj) {
		new SerializedExplicitInstanceConstraint => [
			errorMessage = obj._errorMessage.toValueObject as SerializedValidationIssue
			instance = obj.instance.toValueObject as SerializedAbstractType
			typeScheme = obj.typeScheme.toValueObject as SerializedAbstractType
		]
	}
	
	protected dispatch def Object toValueObject(SubtypeConstraint obj) {
		new SerializedSubtypeConstraint => [
			errorMessage = obj._errorMessage.toValueObject as SerializedValidationIssue
			subType = obj.subType.toValueObject as SerializedAbstractType
			superType = obj.superType.toValueObject as SerializedAbstractType
		]
	}
	
	protected dispatch def Object toValueObject(FunctionTypeClassConstraint obj) {
		new SerializedFunctionTypeClassConstraint => [
			errorMessage = obj._errorMessage.toValueObject as SerializedValidationIssue
			type = obj.typ.toValueObject as SerializedAbstractType
			functionCall = if(obj.functionCall === null) null else EcoreUtil.getURI(obj.functionCall).toString();
			functionReference = obj.functionReference?.toValueObject;
			returnTypeTV = obj.returnTypeTV.toValueObject as SerializedTypeVariable;
			instanceOfQN = obj.instanceOfQN.toString()
			returnTypeVariance = obj.returnTypeVariance;
		]
	}
		
	protected dispatch def Object toValueObject(TypeClass obj) {
		new SerializedTypeClass => [
			instances = obj.instances.entrySet
				.map[ it.key.toValueObject as SerializedAbstractType ->  if(it.value === null) null else EcoreUtil.getURI(it.value).toString() ]
				.toMap([ it.key ], [ it.value ])
		]
	}
	
	protected dispatch def SerializedTypeClassProxy toValueObject(TypeClassProxy obj) {
		new SerializedTypeClassProxy => [
			toResolve = obj.toResolve.toValueObject as SerializedTypeVariableProxy
		]
	}
	
	protected dispatch def Object fill(SerializedAbstractType ctxt, AbstractType obj) {
		ctxt.name = obj.name;
		ctxt.origin = if(obj.origin === null) null else EcoreUtil.getURI(obj.origin).toString()
		return ctxt;
	}
		
	protected dispatch def Object toValueObject(BaseKind obj) {
		new SerializedBaseKind => [
			fill(it, obj)
			kindOf = obj.kindOf.toValueObject as SerializedAbstractType
		]
	}
	
	protected dispatch def Object toValueObject(BottomType obj) {
		new SerializedBottomType => [
			fill(it, obj)
			message = message
		]
	}
	protected dispatch def Object toValueObject(AtomicType obj) {
		new SerializedAtomicType => [
			fill(it, obj)
		]
	}
	
	protected dispatch def Object toValueObject(FloatingType obj) {
		new SerializedFloatingType => [
			fill(it, obj)
			widthInBytes = obj.widthInBytes
		]
	}
	
	protected dispatch def Object toValueObject(IntegerType obj) {
		new SerializedIntegerType => [
			fill(it, obj)
			widthInBytes = obj.widthInBytes
			signedness = obj.signedness
		]
	}
	
	protected dispatch def Object toValueObject(TypeHole obj) {
		new SerializedTypeHole => [
			fill(it, obj);
		]
	}
	
	protected dispatch def Object fill(SerializedCompoundType ctxt, TypeConstructorType obj) {
		_fill(ctxt as SerializedAbstractType, obj as AbstractType);
		ctxt.type = obj.type.toValueObject as SerializedAbstractType
		ctxt.typeArguments = obj.typeArguments.map[ it.toValueObject as SerializedAbstractType ].toList
		return ctxt
	}
	
	protected dispatch def Object fill(SerializedTypeScheme ctxt, TypeScheme obj) {
		_fill(ctxt as SerializedAbstractType, obj as AbstractType);
		ctxt.vars = obj.vars.map[ it.toValueObject as SerializedTypeVariable ].force;
		ctxt.on = obj.on.toValueObject as SerializedAbstractType;
		return ctxt;
	}
	
	protected dispatch def Object toValueObject(FunctionType obj) {
		new SerializedFunctionType => [
			fill(it, obj)
		]
	}
	
	protected dispatch def Object toValueObject(ProdType obj) {
		new SerializedProductType => [ 
			fill(it, obj)
		]
	}
	

	protected dispatch def Object toValueObject(SumType obj) {
		new SerializedSumType => [ 
			fill(it, obj)
		]
	}
	
	protected dispatch def Object toValueObject(TypeConstructorType obj) {
		new SerializedTypeConstructorType => [
			fill(it, obj)
		]
	}
	
	protected dispatch def Object toValueObject(TypeScheme obj) {
		new SerializedTypeScheme => [
			fill(it, obj)
			on = obj.on.toValueObject as SerializedAbstractType
			vars = obj.vars.map[ it.toValueObject as SerializedTypeVariable ].toList
		]
	}
	
	protected dispatch def Object toValueObject(UnorderedArguments obj) {
		new SerializedUnorderedArguments => [
			fill(it, obj)
			it.parameterNames += obj.argParamNamesAndValueTypes.map[it.key];
			it.valueTypes += obj.argParamNamesAndValueTypes.map[it.value.toValueObject as SerializedAbstractType];
		]
	}
	
	protected dispatch def Object toValueObject(TypeVariable obj) {
		new SerializedTypeVariable => [
			fill(it, obj)
		]
	}
	
	protected dispatch def Object toValueObject(TypeVariableProxy obj) {
		new SerializedTypeVariableProxy => [
			fill(it, obj)
			it.reference = obj.reference?.toValueObject as SerializedEReference;
			it.targetQID = obj.targetQID.toString;
			it.ambiguityResolutionStrategy = obj.ambiguityResolutionStrategy;
		]
	}
	

	protected static class MitaJsonSerializer implements JsonSerializer<Object>, JsonDeserializer<Object> {
				
		override serialize(Object src, Type typeOfSrc, JsonSerializationContext context) {
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
			return result as Object;
		}
		
	}
	
}