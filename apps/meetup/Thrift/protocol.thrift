namespace cocoa MCMC

typedef string UserIdentifier

struct TextMessage {
	1: UserIdentifier originator		
	2: string text  
}

union Broadcast {
	1: TextMessage textMessage
}

union DataFrame {
	1: Broadcast broadcast
}
