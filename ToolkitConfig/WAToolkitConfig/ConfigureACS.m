/*
 Copyright 2010 Microsoft Corp
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#import "ConfigureACS.h"
#import "WAMServiceCall.h"
#import "WAMWorkerQueue.h"
#import "WAMultipartMime.h"
#import "WASimpleBase64.h"
#import "NSString+URLEncode.h"

@implementation ConfigureACS

+ (void)addIssuerToQueue:(WAMWorkerQueue *)queue name:(NSString *)providerName withCompletionHandler:(void (^)(long long identity))block
{
	 WAMultipartMime *mime = [queue.client createMimeBody];
	 [mime appendDataWithAtomPubEntity:@"Issuers" 
								  term:@"Issuer",
	  @"Id", EdmInt64, 0L,
	  @"Name", EdmString, providerName,
	  @"SystemReserved", EdmBoolean, false,
	  @"Version", EdmBinary, [NSNull null],
	  nil];
	 
	 [queue.client sendBatch:mime mimeEntryHandler:^(xmlDocPtr doc) 
	  {
		  [WAMXMLHelper parseAtomPub:doc block:^(WAMAtomPubEntry *entry, NSInteger index, BOOL *stop) 
		   {
			   long long issuerKey = [[entry objectForKey:@"Id"] longLongValue];
			   NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithObject:@(issuerKey) forKey:@"Issuer"];
			   [queue setObject:dictionary forKey:providerName];
			   *stop = YES;
			   
				WAMultipartMime *mime = [queue.client createMimeBody];
				[mime appendDataWithAtomPubEntity:@"IdentityProviders" 
											 term:@"IdentityProvider",
				 @"Description", EdmString, [NSNull null],
				 @"DisplayName", EdmString, providerName,
				 @"Id", EdmInt64, 0L,
				 @"IssuerId", EdmInt64, issuerKey,
				 @"LoginLinkName", EdmString, providerName,
				 @"LoginParameters", EdmString, [NSNull null],
				 @"Realm", EdmString, [NSNull null],
				 @"SystemReserved", EdmBoolean, false,
				 @"Version", EdmBinary, [NSNull null],
				 @"WebSSOProtocolType", EdmString, @"OpenId",
				 nil];
				
				[queue.client sendBatch:mime mimeEntryHandler:^(xmlDocPtr doc) 
				 {
					 [WAMXMLHelper parseAtomPub:doc block:^(WAMAtomPubEntry *entry, NSInteger index, BOOL *stop) 
					  {
						  long long identityProviderKey = [[entry objectForKey:@"Id"] longLongValue];
						  dictionary[@"IdentityProvider"] = @(identityProviderKey);
						  *stop = YES;
						  
						  block(identityProviderKey);
					  }];
				 }
				  withCompletionHandler:^(NSError *error) 
				 {
					 if(error)
					 {
						 queue.error = error;
						 return;
					 }
				 }];
		   }];
	  } 
	  withCompletionHandler:^(NSError *error) 
	  {
		  if(error)
		  {
			  queue.error = error;
			  return;
		  }
	  }];
}

+ (void)addRelyingPartiesWithQueue:(WAMWorkerQueue *)queue identity:(long long)identity withCompletionHandler:(void(^)())block
{
	[queue.client getFromEntity:@"RelyingParties" withXmlCompletionHandler:^(xmlDocPtr doc, NSError *error) {
		if(error)
		{
			queue.error = error;
			return;
		}
		
		__weak NSMutableArray *array = [NSMutableArray arrayWithCapacity:10];
		
		// see if we can find this entry...
		[WAMXMLHelper parseAtomPub:doc block:^(WAMAtomPubEntry *entry, NSInteger index, BOOL *stop) 
		 {
			 [array addObject:[entry objectForKey:@"Id"]];
		 }];
		
		WAMultipartMime *mime = [queue.client createMimeBody];
		
		for(NSString *idStr in array)
		{
			[mime appendDataWithAtomPubEntity:@"RelyingPartyIdentityProviders" 
										 term:@"RelyingPartyIdentityProvider",
			 @"Id", EdmInt64, 0L,
			 @"IdentityProviderId", EdmInt64, identity,
			 @"RelyingPartyId", EdmInt64, [idStr longLongValue],
			 @"SystemReserved", EdmBoolean, false,
			 @"Version", EdmBinary, [NSNull null],
			 nil];
		}
		
		[queue.client sendBatch:mime mimeEntryHandler:^(xmlDocPtr doc) 
		 {
			 [WAMXMLHelper parseAtomPub:doc block:^(WAMAtomPubEntry *entry, NSInteger index, BOOL *stop) 
			  {					  
			  }];
		 }
		  withCompletionHandler:^(NSError *error) 
		 {
			 if(error)
			 {
				 queue.error = error;
				 return;
			 }

			 block();
		 }];
	}];
}

+ (void)addRelyingPartyWithQueue:(WAMWorkerQueue *)queue name:(NSString *)name withCompletionHandler:(void(^)())block
{
	void (^completionBlock)() = ^()
	{
		WAMultipartMime* mime = [queue.client createMimeBody];
		
		[mime appendDataWithAtomPubEntity:@"RelyingParties" 
									 term:@"RelyingParty",
		 @"AsymmetricTokenEncryptionRequired", EdmBoolean, NO,
		 @"Description", EdmString, name,
		 @"DisplayName", EdmString, name,
		 @"Id", EdmInt64, 0L,
		 @"Name", EdmString, name,
		 @"SystemReserved", EdmBoolean, false,
		 @"TokenLifetime", EdmInt32, 86400,	// = 24hrs * 60mins * 60secs
		 @"TokenType", EdmString, @"SWT",
		 @"Version", EdmBinary, [NSNull null],
		 nil];
		
		[queue.client sendBatch:mime mimeEntryHandler:^(xmlDocPtr doc) 
		 {
			 [WAMXMLHelper parseAtomPub:doc block:^(WAMAtomPubEntry *entry, NSInteger index, BOOL *stop) 
			  {			
				  NSString *idStr = [entry objectForKey:@"Id"];
				  if(idStr)
				  {
					  long long idValue = idValue = [idStr longLongValue];
					  
					  [queue setObject:@(idValue) forKey:@"RelyingParty"];
				  }
			  }];
		 }
		  withCompletionHandler:^(NSError *error) 
		 {
			 if(error)
			 {
				 queue.error = error;
				 return;
			 }
			 
			 block();
		 }];
	};
	
	NSString *relyingParties = [NSString stringWithFormat:@"RelyingParties()?$filter=Name%%20eq%%20'%@'&$top=1", [name URLEncode]];
	queue.status = @"Configuring relying party";

	[queue.client getFromEntity:relyingParties withXmlCompletionHandler:^(xmlDocPtr doc, NSError *error) 
	{
		if(error)
		{
			queue.error = error;
			return;
		}
		
		__block BOOL found = NO;
		
		// see if we can find this entry...
		[WAMXMLHelper parseAtomPub:doc block:^(WAMAtomPubEntry *entry, NSInteger index, BOOL *stop) 
		 {
			 NSString *idStr = [entry objectForKey:@"Id"];
			 if(idStr)
			 {
				 found = YES;
				 
				 long long idValue = idValue = [idStr longLongValue];
				 NSString *issuer = [NSString stringWithFormat:@"RelyingParties(%qdL)", idValue];
				 
				 // if we find it, delete it!
				  [queue.client deleteFromEntity:issuer withCompletionHandler:^(NSError *error) 
				   {
					   if(error)
					   {
						   queue.error = error;
						   return;
					   }
					   
					   // ensure its gone!
					   [queue.client getFromEntity:relyingParties atomEntryHandler:^(WAMAtomPubEntry *entry, BOOL *stop) 
					   {
						   LOGLINE(@"Relying party is still there!");
						   *stop = YES;
					   } 
					   withCompletionHandler:^(NSError *error) 
					   {
						   if(error)
						   {
							   queue.error = error;
							   return;
						   }
						   
						   completionBlock();
					   }];
				  }];
			 }
			 
			 *stop = YES;
		 }];
		
		if(!found)
		{
			completionBlock();
		}
	}];
}

+ (void)addRulesWithQueue:(WAMWorkerQueue *)queue name:(NSString *)name group:(NSString *)group realm:(NSString *)realm signingKey:(NSString *)signingKey withCompletionHandler:(void(^)(long long ruleGroupId))block
{
	void (^completionBlock)() = ^()
	{
		WAMultipartMime *mime = [queue.client createMimeBody];
		
		[mime appendDataWithAtomPubEntity:@"RuleGroups" 
									 term:@"RuleGroup",
			 @"Id", EdmInt64, 0L,
			 @"Name", EdmString, group,
			 @"SystemReserved", EdmBoolean, false,
			 @"Version", EdmBinary, [NSNull null],
			 nil];
		
		[queue.client sendBatch:mime mimeEntryHandler:^(xmlDocPtr doc) 
		 {
			 [WAMXMLHelper parseAtomPub:doc block:^(WAMAtomPubEntry *entry, NSInteger index, BOOL *stop) 
			  {			
				  NSString *idStr = [entry objectForKey:@"Id"];
				  if(idStr)
				  {
					  long long idValue = idValue = [idStr longLongValue];
					  
					  [queue setObject:@(idValue) forKey:@"RuleGroup"];
					  
					  WAMultipartMime *mime = [queue.client createMimeBody];
					  long long relyingParty = [[queue objectForKey:@"RelyingParty"] longLongValue];
					  
					  [mime appendDataWithAtomPubEntity:@"RelyingPartyRuleGroups" 
												   term:@"RelyingPartyRuleGroup",
						   @"Id", EdmInt64, 0L,
						   @"RelyingPartyId", EdmInt64, relyingParty,
						   @"RuleGroupId", EdmInt64, idValue,
						   @"SystemReserved", EdmBoolean, false,
						   @"Version", EdmBinary, [NSNull null],
						   nil];
					  
					  [mime appendDataWithAtomPubEntity:@"RelyingPartyAddresses" 
												   term:@"RelyingPartyAddress",
					       @"Address", EdmString, realm,
					       @"EndpointType", EdmString, @"Realm",
						   @"Id", EdmInt64, 0L,
						   @"RelyingPartyId", EdmInt64, relyingParty,
						   @"SystemReserved", EdmBoolean, false,
						   @"Version", EdmBinary, [NSNull null],
						   nil];
					  
					  NSDate *now = [NSDate date];
					  NSCalendar *cal = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
					  NSDateComponents *components = [[NSDateComponents alloc] init];
					  [components setYear:1];
					  NSDate *oneYearLater = [cal dateByAddingComponents:components toDate:now options:0];
					  
					  [mime appendDataWithAtomPubEntity:@"RelyingPartyKeys" 
												   term:@"RelyingPartyKey",
						   @"DisplayName", EdmString, [NSString stringWithFormat:@"Signing key for %@", name],
						   @"EndDate", EdmDateTime, oneYearLater,
						   @"Id", EdmInt64, 0L,
						   @"IsPrimary", EdmBoolean, true,
						   @"Password", EdmBinary, [NSNull null],
						   @"RelyingPartyId", EdmInt64, relyingParty,
						   @"StartDate", EdmDateTime, now,
						   @"SystemReserved", EdmBoolean, false,
						   @"Type", EdmString, @"Symmetric",
						   @"Usage", EdmString, @"Signing",
						   @"Value", EdmBinary, signingKey,
						   @"Version", EdmBinary, [NSNull null],
						   nil];
					  
					  [queue.client sendBatch:mime mimeEntryHandler:^(xmlDocPtr doc) 
					   {
						   [WAMXMLHelper parseAtomPub:doc block:^(WAMAtomPubEntry *entry, NSInteger index, BOOL *stop) 
							{			
								NSString *idStr = [entry objectForKey:@"Id"];
								if(idStr)
								{
									NSNumber *num = @([idStr longLongValue]);
									
									switch(index)
									{
										case 0:
										{
											[queue setObject:num forKey:@"RelyingPartyRuleGroup"];
											break;
										}
											
										case 1:
										{
											[queue setObject:num forKey:@"RelyingPartyAddress"];
											break;
										}
											
										case 2:
										{
											[queue setObject:num forKey:@"RelyingPartyKey"];
											break;
										}
									}
								}
							}];
					   }
						withCompletionHandler:^(NSError *error) 
					   {
						   if(error)
						   {
							   queue.error = error;
							   return;
						   }
						   
						   block(idValue);
					   }];
				  }
			  }];
		 }
		  withCompletionHandler:^(NSError *error) 
		 {
			 if(error)
			 {
				 queue.error = error;
				 return;
			 }
		 }];
	};
	
	NSString *ruleGroups = [NSString stringWithFormat:@"RuleGroups()?$filter=Name%%20eq%%20'%@'&$top=1", [group URLEncode]];

	queue.status = @"Configuring rule groups";
	
	[queue.client getFromEntity:ruleGroups withXmlCompletionHandler:^(xmlDocPtr doc, NSError *error) 
	{
		if(error)
		{
			queue.error = error;
			return;
		}
		
		__block BOOL found = NO;
		
		// see if we can find this entry...
		[WAMXMLHelper parseAtomPub:doc block:^(WAMAtomPubEntry *entry, NSInteger index, BOOL *stop) 
		 {
			 NSString *idStr = [entry objectForKey:@"Id"];
			 if(idStr)
			 {
				 found = YES;
				 
				 long long idValue = idValue = [idStr longLongValue];
				 NSString *ruleGroup = [NSString stringWithFormat:@"RuleGroups(%qdL)", idValue];
				 
				 // if we find it, delete it!
				  [queue.client deleteFromEntity:ruleGroup withCompletionHandler:^(NSError *error) 
				   {
					   if(error)
					   {
						   queue.error = error;
						   return;
					   }
					   
					   // ensure its gone!
					   [queue.client getFromEntity:ruleGroups atomEntryHandler:^(WAMAtomPubEntry *entry, BOOL *stop) 
					   {
						   LOGLINE(@"Rule Group is still there!");
						   *stop = YES;
					   } 
					   withCompletionHandler:^(NSError *error) 
					   {
						   if(error)
						   {
							   queue.error = error;
							   return;
						   }
						   
						   completionBlock();
					   }];
				  }];
			 }
			 
			 *stop = YES;
		 }];
		
		if(!found)
		{
			completionBlock();
		}
	}];
}

+ (void)addSignInWithQueue:(WAMWorkerQueue *)queue 
				  identity:(long long)identity 
			  providerName:(NSString *)providerName 
				  endpoint:(NSString *)endpoint
	 withCompletionHandler:(void (^)())block
{
	WAMultipartMime *mime = [queue.client createMimeBody];
	
	[mime appendDataWithAtomPubEntity:@"IdentityProviderAddresses" 
								 term:@"IdentityProviderAddress",
		 @"Address", EdmString, endpoint,
		 @"EndpointType", EdmString, @"SignIn",
		 @"Id", EdmInt64, 0L,
		 @"IdentityProviderId", EdmInt64, identity,
		 @"SystemReserved", EdmBoolean, false,
		 @"Version", EdmBinary, [NSNull null],
		 nil];
	
	[queue.client sendBatch:mime mimeEntryHandler:^(xmlDocPtr doc) 
	 {
		 [WAMXMLHelper parseAtomPub:doc block:^(WAMAtomPubEntry *entry, NSInteger index, BOOL *stop) 
		  {			
			  NSString *idStr = [entry objectForKey:@"Id"];
			  if(idStr)
			  {
				  long long idValue = idValue = [idStr longLongValue];
				  
				  NSMutableDictionary *dict = [queue objectForKey:providerName];
				  dict[@"IdentityProviderAddresses"] = @(idValue);
			  }
		  }];
	 }
	 withCompletionHandler:^(NSError *error)
	 {
		 if(error)
		 {
			 queue.error = error;
		 }
		 
		 block();
	 }];
}

+ (void)getIdentityProvider:(WAMWorkerQueue *)queue providerName:(NSString *)providerName withCompletionHandler:(void (^)())block
{
	NSString *identityProviders = [NSString stringWithFormat:@"IdentityProviders()?$filter=DisplayName%%20eq%%20'%@'&$top=1", [providerName URLEncode]];

	[queue.client getFromEntity:identityProviders withXmlCompletionHandler:^(xmlDocPtr doc, NSError *error) 
	 {
		 if(error)
		 {
			 queue.error = error;
			 return;
		 }

		 // see if we can find this entry...
		 [WAMXMLHelper parseAtomPub:doc block:^(WAMAtomPubEntry *entry, NSInteger index, BOOL *stop) 
		  {
			  NSString *idStr = [entry objectForKey:@"Id"];
			  if(idStr)
			  {
				  long long idValue = idValue = [idStr longLongValue];
				  NSMutableDictionary* d = [NSMutableDictionary dictionaryWithObject:@(idValue) 
																			  forKey:@"IdentityProvider"];
				  [queue setObject:d forKey:providerName];
			  }
		  }];
		 
		 block();
	 }];
}

+ (void)addIdentityProviderWithQueue:(WAMWorkerQueue *)queue providerName:(NSString *)providerName endpoint:(NSString *)endpoint withCompletionHandler:(void (^)())block
{
	void (^completionBlock)() = ^
	{
		[self addIssuerToQueue:queue name:providerName withCompletionHandler:^(long long identity) 
		 {
			 [self addSignInWithQueue:queue identity:identity providerName:providerName endpoint:endpoint withCompletionHandler:^ 
			 {
				 [self addRelyingPartiesWithQueue:queue identity:identity withCompletionHandler:^ 
				  {
					  block();
				  }];
			 }];
		 }];
	};
	
	NSString *issuers = [NSString stringWithFormat:@"Issuers()?$filter=Name%%20eq%%20'%@'&$top=1", [providerName URLEncode]];
	queue.status = [NSString stringWithFormat:@"Configuring %@ provider", providerName];
	
	[queue.client getFromEntity:issuers withXmlCompletionHandler:^(xmlDocPtr doc, NSError *error) 
	{
		if(error)
		{
			queue.error = error;
			return;
		}
		
		__block BOOL found = NO;
		
		// see if we can find this entry...
		[WAMXMLHelper parseAtomPub:doc block:^(WAMAtomPubEntry *entry, NSInteger index, BOOL *stop) 
		 {
			 NSString *idStr = [entry objectForKey:@"Id"];
			 if(idStr)
			 {
				 found = YES;
				 
				 long long idValue = idValue = [idStr longLongValue];
				 NSString *issuer = [NSString stringWithFormat:@"Issuers(%qdL)", idValue];
				 
				 // if we find it, delete it!
				  [queue.client deleteFromEntity:issuer withCompletionHandler:^(NSError *error) 
				   {
					   if(error)
					   {
						   queue.error = error;
						   return;
					   }
					   
					   // ensure its gone!
					   NSString *ids = [NSString stringWithFormat:@"IdentityProviders()?$filter=DisplayName%%20eq%%20'%@'&$top=1", [providerName URLEncode]];
					   [queue.client getFromEntity:ids atomEntryHandler:^(WAMAtomPubEntry *entry, BOOL *stop) 
					   {
						   NSLog(@"Identity provider is still there!");
						   *stop = YES;
					   } 
					   withCompletionHandler:^(NSError *error) 
					   {
						   if(error)
						   {
							   queue.error = error;
							   return;
						   }
						   
						   [queue.client getFromEntity:issuers atomEntryHandler:^(WAMAtomPubEntry *entry, BOOL *stop) 
							{
								NSLog(@"Issuer is still there!");
								*stop = YES;
							} 
							withCompletionHandler:^(NSError *error) 
							{
								if(error)
								{
									queue.error = error;
									return;
								}
								
								completionBlock();
							}];
					   }];
				  }];
			 }
			 
			 *stop = YES;
		 }];
		
		if(!found)
		{
			completionBlock();
		}
	}];
}

+ (void) processPassthoughRulesWithQueue:(WAMWorkerQueue *)queue 
								   names:(NSMutableArray *)names 
								requests:(NSMutableArray *)requests 
				   withCompletionHandler:(void(^)())block
{
	WAMultipartMime *mime = [requests lastObject];
	NSString *key = [names lastObject];
	
	[queue.client sendBatch:mime mimeEntryHandler:^(xmlDocPtr doc) 
	 {
		 [WAMXMLHelper parseAtomPub:doc block:^(WAMAtomPubEntry *entry, NSInteger index, BOOL *stop) 
		  {			
			  NSString *idStr = [entry objectForKey:@"Id"];
			  if(idStr)
			  {
				  NSNumber *num = @([idStr longLongValue]);
				  
				  NSMutableDictionary *dict = [queue objectForKey:key];
				  if(!dict)
				  {
					  dict = [NSMutableDictionary dictionaryWithCapacity:10];
					  [queue setObject:dict forKey:key];
				  }
				  
				  dict[@"Rule"] = num;
			  }
		  }];
	 }
	  withCompletionHandler:^(NSError *error) 
	 {
		 if(error)
		 {
			 queue.error = error;
			 return;
		 }
		 
		 [names removeLastObject];
		 [requests removeLastObject];
		 
		 if(names.count)
		 {
			 [self processPassthoughRulesWithQueue:queue names:names requests:requests withCompletionHandler:block];
		 }
		 else
		 {
			 block();
		 }
	 }];
}

+ (void)addPassthroughRulesWithQueue:(WAMWorkerQueue *)queue 
						  ruleGroupId:(long long)ruleGroupId
					identityProviders:(NSArray *)identityProviders
				withCompletionHandler:(void(^)())block
{
	queue.status = @"Configuring passthrough rules";
		
	[queue.client getFromEntity:@"IdentityProviders" withXmlCompletionHandler:^(xmlDocPtr doc, NSError *error) 
	 {
		 NSMutableArray *names = [NSMutableArray arrayWithCapacity:identityProviders.count];
		 NSMutableArray *requests = [NSMutableArray arrayWithCapacity:identityProviders.count];
		 
		 [WAMXMLHelper parseAtomPub:doc block:^(WAMAtomPubEntry *entry, NSInteger index, BOOL *stop) 
		 {
			 NSString *displayName = [entry objectForKey:@"DisplayName"];
			 
			 if([identityProviders indexOfObject:displayName] == NSNotFound)
			 {
				 return;
			 }
			 
			 if(names.count)
			 {
				 [names insertObject:displayName atIndex:0];
			 }
			 else
			 {
				 [names addObject:displayName];
			 }

			 WAMultipartMime *mime = [queue.client createMimeBody];
			 long long issuerIdValue = [[entry objectForKey:@"IssuerId"] longLongValue];
			 
			 [mime appendDataWithAtomPubEntity:@"Rules" 
										  term:@"Rule",
				  @"Description", EdmString, [NSString stringWithFormat:@"Passthrough any claim from %@", displayName],
				  @"Id", EdmInt64, 0L,
				  @"InputClaimType", EdmString, [NSNull null],
				  @"InputClaimValue", EdmString, [NSNull null],
				  @"IssuerId", EdmInt64, issuerIdValue,
				  @"OutputClaimType", EdmString, [NSNull null],
				  @"OutputClaimValue", EdmString, [NSNull null],
				  @"RuleGroupId", EdmInt64, ruleGroupId,
				  @"SystemReserved", EdmBoolean, false,
				  @"Version", EdmBinary, [NSNull null],
				  nil];
			 
			 if(requests.count)
			 {
				 [requests insertObject:mime atIndex:0];
			 }
			 else
			 {
				 [requests addObject:mime];
			 }
		 }];
		 
		 if(names.count)
		 {
			 [self processPassthoughRulesWithQueue:queue names:names requests:requests withCompletionHandler:block];
		 }
	 }];
}

+ (void)processPartyIdentityWithQueue:(WAMWorkerQueue *)queue 
								 names:(NSMutableArray *)names 
							  requests:(NSMutableArray *)requests 
				 withCompletionHandler:(void(^)())block
{
	WAMultipartMime *mime = [requests lastObject];
	NSString *key = [names lastObject];
	
	[queue.client sendBatch:mime mimeEntryHandler:^(xmlDocPtr doc) 
	 {
		 [WAMXMLHelper parseAtomPub:doc block:^(WAMAtomPubEntry *entry, NSInteger index, BOOL *stop) 
		  {			
			  NSString *idStr = [entry objectForKey:@"Id"];
			  if(idStr)
			  {
				  NSNumber *num = @([idStr longLongValue]);
				  
				  NSMutableDictionary *dict = [queue objectForKey:key];
				  dict[@"RelyingPartyIdentityProvider"] = num;
			  }
		  }];
	 }
	  withCompletionHandler:^(NSError *error) 
	 {
		 if(error)
		 {
			 queue.error = error;
			 return;
		 }
		 
		 [names removeLastObject];
		 [requests removeLastObject];
		 
		 if(names.count)
		 {
			 [self processPartyIdentityWithQueue:queue names:names requests:requests withCompletionHandler:block];
		 }
		 else
		 {
			 block();
		 }
	 }];
}

+ (void)bindPartyIdentitiesWithQueue:(WAMWorkerQueue *)queue identityProviders:(NSArray *)identityProviders withCompletionHandler:(void(^)())block
{
	NSMutableArray *names = [NSMutableArray arrayWithCapacity:identityProviders.count];
	NSMutableArray *requests = [NSMutableArray arrayWithCapacity:identityProviders.count];

	long long relyingParty = [[queue objectForKey:@"RelyingParty"] longLongValue];
	
	for(NSString *key in identityProviders)
	{
		[names addObject:key];
		
		NSDictionary *dict = [queue objectForKey:key];
		long long identityProvider = [dict[@"IdentityProvider"] longLongValue];
		
		WAMultipartMime *mime = [queue.client createMimeBody];
		
		[mime appendDataWithAtomPubEntity:@"RelyingPartyIdentityProviders" 
									 term:@"RelyingPartyIdentityProvider",
		 @"Id", EdmInt64, 0L,
		 @"IdentityProviderId", EdmInt64, identityProvider,
		 @"RelyingPartyId", EdmInt64, relyingParty,
		 @"SystemReserved", EdmBoolean, false,
		 @"Version", EdmBinary, [NSNull null],
		 nil];
		
		[requests addObject:mime];
	}
	
	if(names)
	{
		[self processPartyIdentityWithQueue:queue names:names requests:requests withCompletionHandler:block];
	}
}

+ (void)configureACSWithServiceNamespace:(NSString *)serviceNamespace 
							managementKey:(NSString *)managementKey 
									realm:(NSString *)realm
						 relyingPartyName:(NSString *)relyingPartyName
								groupName:(NSString *)groupName
							   signingKey:(NSString *)signingKey
						   statusCallback:(void(^)(NSString *))status 
					withCompletionHandler:(void(^)(NSDictionary *values, NSError *error))block
{
	if(!signingKey)
	{
		SecKeyRef keyRef = NULL;
        /*
		SecKeyGenerate(NULL,			// keychainRef,
                       CSSM_ALGID_AES,	// algorithm
                       256,				// bits
                       0L,				// contextHandle
                       CSSM_KEYUSE_ANY,	// keyUsage
                       CSSM_KEYATTR_RETURN_DEFAULT | CSSM_KEYATTR_EXTRACTABLE, // keyAttr
                       NULL,			// initialAccess
                       &keyRef);
        */
        CFErrorRef error = NULL;
        
        // Create the dictionary of key parameters
        CFMutableDictionaryRef parameters = (__bridge CFMutableDictionaryRef)[NSMutableDictionary dictionaryWithObjectsAndKeys:kSecAttrKeyTypeAES, kSecAttrKeyType, (CFNumberRef)@256, kSecAttrKeySizeInBits, nil];
        
        keyRef = SecKeyGenerateSymmetric(parameters, &error);
					
		CFDataRef data = NULL;
		NSData *nsd;
		//SecKeychainItemExport((CFTypeRef)keyRef, kSecFormatRawKey, 0, NULL, &data),
        
        SecItemExport((CFTypeRef)keyRef, kSecFormatRawKey, 0, NULL, &data),
		
        CFRelease(keyRef);
	
		nsd = (__bridge NSData*)data;
		signingKey = [nsd stringWithBase64EncodedData];
		
		CFRelease(data);
	}
	
	WAMWorkerQueue *queue = [WAMWorkerQueue new];
	
	[queue setObject:signingKey forKey:@"TokenSigningKey"];

	[queue setStatusTarget:status];
	[queue setCompletionHandler:^(WAMWorkerQueue *queue) {
		if(queue.error)
		{
			block(nil, queue.error);
		}
		else
		{
			block(queue.values, nil);
		}
		
	}];
	
	queue.status = @"Authenticating";
	 
	[WAMServiceCall obtainTokenFromNamespace:serviceNamespace
							managementKey:managementKey
					withCompletionHandler:^(NSInteger statusCode, NSError *error, WAMServiceCall *client)
	 {
		 if(error)
		 {
			 queue.error = error;
             block(nil, error);
			 return;
		 }

		 queue.client = client;
		  
		 // set up the Google issuer and identity provider
		 [self addIdentityProviderWithQueue:queue providerName:@"Google" endpoint:@"https://www.google.com/accounts/o8/ud" withCompletionHandler:^
		 {
			// now set up the Yahoo! issuer and identity provider
			[self addIdentityProviderWithQueue:queue providerName:@"Yahoo!" endpoint:@"https://open.login.yahooapis.com/openid/op/auth" withCompletionHandler:^
			 {
				 [self getIdentityProvider:queue providerName:@"Windows Live ID" withCompletionHandler:^
				  {
					 // ... add the relying party...
					 [self addRelyingPartyWithQueue:queue name:relyingPartyName withCompletionHandler:^ 
					  {
						  NSArray* providers = @[@"Windows Live ID", @"Google", @"Yahoo!"];
						  
						  [self bindPartyIdentitiesWithQueue:queue identityProviders:providers withCompletionHandler:^
						   {
							   // ... add the rule groups...
							   [self addRulesWithQueue:queue name:relyingPartyName group:groupName realm:realm signingKey:signingKey withCompletionHandler:^ (long long ruleGroupId)
								{
									[self addPassthroughRulesWithQueue:queue 
														   ruleGroupId:ruleGroupId
													 identityProviders:providers
												 withCompletionHandler:^
									 {
										 [queue processLast];
									 }];
								}];
						   }];
					  }];
				  }];
			 }];
		}];
	}];
}

@end
