class Order {
    id: number
    next_id: number
    prev_id: number
    is_buy: boolean
    price: number
    amount: number
    filled: number
    dt: string
    owner: string
    limit_id: number

    constructor(
        _id: number,
        _next_id: number,
        _prev_id: number,
        _is_buy: boolean,
        _price: number,
        _amount: number,
        _filled: number,
        _dt: string,
        _owner: string,
        _limit_id: number
    ) {
        this.id = _id
        this.next_id = _next_id
        this.prev_id = _prev_id
        this.is_buy = _is_buy
        this.price = _price
        this.amount = _amount
        this.filled = _filled
        this.dt = _dt
        this.owner = _owner
        this.limit_id = _limit_id
    }

    getOrder() {
        return this
    }

    setOrder(newOrder: Order) {
        this.id = newOrder.id
        this.next_id = newOrder.next_id
        this.prev_id = newOrder.prev_id
        this.is_buy = newOrder.is_buy
        this.price = newOrder.price
        this.amount = newOrder.amount
        this.filled = newOrder.filled
        this.dt = newOrder.dt
        this.owner = newOrder.owner
        this.limit_id = newOrder.limit_id
    }
}
