class Limit {
    head_id: number | null
    tail_id: number | null
    length: number
    curr_order_id: number

    constructor() {
        this.head_id = null
        this.tail_id = null
        this.length = 0
        this.curr_order_id = 1
    }

    push(newOrder: Order) {
        // If list is empty, set head and tail to new node
        if (this.length === 0) {
            this.head_id = newOrder.id
            this.tail_id = newOrder.id
        }
        // Otherwise, add node to list
        else {
            this.tail.next = newNode
            newNode.prev = this.tail
            this.tail = newNode
        }
        // Increment length counter
        this.length += 1
        // Return linked list
        return this
    }
}
