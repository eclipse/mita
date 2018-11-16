/**
 * Copyright (c) 2015 committers of YAKINDU and others.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 * Contributors:
 * 	committers of YAKINDU - initial API and implementation
 * 
 */
package org.eclipse.mita.base.types.validation;

import java.util.List;

import org.eclipse.core.runtime.Assert;
import org.eclipse.emf.ecore.EObject;
import org.eclipse.emf.ecore.EStructuralFeature;
import org.eclipse.mita.base.types.validation.IValidationIssueAcceptor.ValidationIssue.Severity;

import com.google.common.base.Predicate;
import com.google.common.collect.Iterables;
import com.google.common.collect.Lists;

/**
 * @author andreas muelder - Initial contribution and API
 * 
 */
public interface IValidationIssueAcceptor {

	public static class ValidationIssue {
		public static enum Severity {
			ERROR, WARNING, INFO
		}

		private Severity severity;
		private String message;
		private String issueCode;
		private EObject target;
		private EStructuralFeature feature;

		public ValidationIssue(Severity severity, String message, String issueCode) {
			this(severity, message, null, null, issueCode);
		}
		
		public ValidationIssue(ValidationIssue self, String newMessage) {
			this.message = newMessage;
			this.severity = self.severity;
			this.issueCode = self.issueCode;
			this.target = self.target;
			this.feature = self.feature;
		}
		
		public ValidationIssue(Severity severity, String message, EObject target, EStructuralFeature feature, String issueCode) {
			Assert.isNotNull(message);
			Assert.isNotNull(issueCode);
			Assert.isNotNull(severity);
			this.severity = severity;
			this.message = message;
			this.target = target;
			this.issueCode = issueCode;
			this.feature = feature;
		}

		public Severity getSeverity() {
			return severity;
		}

		public void setSeverity(Severity severity) {
			this.severity = severity;
		}
		
		public String getMessage() {
			return message;
		}

		public void setMessage(String message) {
			this.message = message;
		}

		public EObject getTarget() {
			return target;
		}

		public void setTarget(EObject target) {
			this.target = target;
		}
		
		public EStructuralFeature getFeature() {
			return feature;
		}

		public void setFeature(EStructuralFeature feature) {
			this.feature = feature;
		}

		public String getIssueCode() {
			return issueCode;
		}

		@Override
		public String toString() {
			return "ValidationIssue [severity=" + severity + ", message=" + message + ", issueCode=" + issueCode
					+ ", target=" + target + "]";
		}

	}

	public void accept(ValidationIssue trace);
	
	public static final class ListBasedValidationIssueAcceptor implements IValidationIssueAcceptor {

		private List<ValidationIssue> traces = Lists.newArrayList();

		@Override
		public void accept(ValidationIssue trace) {
			traces.add(trace);
		}

		public List<ValidationIssue> getTraces() {
			return traces;
		}

		public List<ValidationIssue> getTraces(final Severity severity) {
			return Lists.newArrayList(Iterables.filter(traces, new Predicate<ValidationIssue>() {
				@Override
				public boolean apply(ValidationIssue input) {
					return input.getSeverity() == severity;
				}
			}));
		}

	}

}
