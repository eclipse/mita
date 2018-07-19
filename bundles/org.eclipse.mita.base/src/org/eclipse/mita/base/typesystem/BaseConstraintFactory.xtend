package org.eclipse.mita.base.typesystem

import com.google.inject.Inject
import java.util.regex.Pattern
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.types.GeneratedType
import org.eclipse.mita.base.types.NativeType
import org.eclipse.mita.base.types.PrimitiveType
import org.eclipse.mita.base.types.StructureType
import org.eclipse.mita.base.types.SumAlternative
import org.eclipse.mita.base.types.Type
import org.eclipse.mita.base.types.TypeParameter
import org.eclipse.mita.base.types.TypeSpecifier
import org.eclipse.mita.base.typesystem.constraints.Equality
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.solver.SymbolTable
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.AtomicType
import org.eclipse.mita.base.typesystem.types.IntegerType
import org.eclipse.mita.base.typesystem.types.ProdType
import org.eclipse.mita.base.typesystem.types.SumType
import org.eclipse.mita.base.typesystem.types.TypeScheme
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.xtext.naming.IQualifiedNameProvider
import org.eclipse.xtext.scoping.IScopeProvider
import com.google.common.collect.Lists
import org.eclipse.mita.base.types.ExceptionTypeDeclaration
import org.eclipse.mita.base.typesystem.infra.TypeVariableAdapter
import org.eclipse.mita.base.types.TypedElement

class BaseConstraintFactory implements IConstraintFactory {
	
	@Inject
	protected IQualifiedNameProvider nameProvider;
	
	@Inject
	protected ConstraintSystemProvider constraintSystemProvider;
	
	@Inject
	protected IScopeProvider scopeProvider;
	
	public override ConstraintSystem create(SymbolTable symbols, EObject context) {
		val result = constraintSystemProvider.get(symbols);
		result.computeConstraints(context);
		return result;
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, EObject context) {
		println('''computeConstraints is not implemented for «context.eClass.name»''');
		system.computeConstraintsForChildren(context);
		return null;
	}
	
	protected def void computeConstraintsForChildren(ConstraintSystem system, EObject context) {
		context.eContents.forEach[ system.computeConstraints(it) ]
	}

	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, Type type) {
		system.associate(system.translateTypeDeclaration(type), type);
	}

	protected dispatch def AbstractType translateTypeDeclaration(ConstraintSystem system, PrimitiveType type) {
		val intPatternMatcher = Pattern.compile("(int|uint)(\\d+)$").matcher(type?.name ?: "");
		if(intPatternMatcher.matches) {
			val signed = intPatternMatcher.group(1) == 'int';
			val size = Integer.parseInt(intPatternMatcher.group(2)) / 8;
			
			new IntegerType(type, size, signed);
		} else {
			new AtomicType(type, type.name);
		}
	}

	protected dispatch def AbstractType translateTypeDeclaration(ConstraintSystem system, TypeParameter type) {
		return TypeVariableAdapter.get(type);
	}
	
	protected dispatch def AbstractType translateTypeDeclaration(ConstraintSystem system, StructureType structType) {
		val types = structType.accessorsTypes.map[ system.computeConstraints(it) as AbstractType ].force();
		return new ProdType(structType, types);
	}
	
	protected dispatch def AbstractType translateTypeDeclaration(ConstraintSystem system, org.eclipse.mita.base.types.SumType sumType) {
		val types = sumType.alternatives.map[ system.computeConstraints(it) as AbstractType ].force();
		return new SumType(sumType, types);
	}
	
	protected dispatch def AbstractType translateTypeDeclaration(ConstraintSystem system, SumAlternative sumAlt) {
		val types = sumAlt.accessorsTypes.map[ system.computeConstraints(it) as AbstractType ].force();
		return new ProdType(sumAlt, types);
	}
	
	protected dispatch def AbstractType translateTypeDeclaration(ConstraintSystem system, GeneratedType genType) {
		val typeParameters = genType.typeParameters;
		val typeArgs = typeParameters.map[ system.computeConstraints(it) ].force();
		val atomicType = new AtomicType(genType, genType.name, typeArgs.map[it as AbstractType].force());
		if(typeParameters.empty) {
			return atomicType;
		}
		else {
			return new TypeScheme(genType, typeArgs, atomicType);
		}
	}
	
	protected dispatch def AbstractType translateTypeDeclaration(ConstraintSystem system, ExceptionTypeDeclaration genType) {
		return new AtomicType(genType, genType.name);
	}
	
	protected dispatch def AbstractType translateTypeDeclaration(ConstraintSystem system, EObject genType) {
		println('''No translateTypeDeclaration for «genType.eClass»''');
		return new AtomicType(genType);
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, TypeSpecifier typeSpecifier) {
		val typeArguments = typeSpecifier.typeArguments;
		if(typeArguments.empty) {
			system.associate(system.computeConstraints(typeSpecifier.type))
		}
		else {
			val vars_typeScheme = system.translateTypeDeclaration(typeSpecifier.type).instantiate();
			val vars = vars_typeScheme.key;
			for(var i = 0; i < Integer.min(typeArguments.size, vars.size); i++) {
				system.addConstraint(new Equality(vars.get(i), system.computeConstraints(typeArguments.get(i))));
			}
			system.associate(vars_typeScheme.value, typeSpecifier);
		}
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, NativeType enumerator) {
		return system.associate(new AtomicType(enumerator, enumerator.name));
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, TypedElement element) {
		return system.associate(system.computeConstraints(element.typeSpecifier), element);
	}

	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, Void context) {
		println('computeConstraints called on null');
		return null;
	}
	
	protected def associate(ConstraintSystem system, AbstractType t) {
		return associate(system, t, t.origin);
	}
	
	protected def associate(ConstraintSystem system, AbstractType t, EObject typeVarOrigin) {
		if(typeVarOrigin === null) {
			throw new UnsupportedOperationException("Associating a type variable without origin is not supported (on purpose)!");
		}
		
		val typeVar = TypeVariableAdapter.get(typeVarOrigin);
		if(typeVar != t && t !== null) {
			system.addConstraint(new Equality(typeVar, t));
		}
		return typeVar;	
	}
	
	protected def <T> force(Iterable<T> list) {
		return Lists.newArrayList(list);
	}
	
}